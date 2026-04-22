-- 017_teams.sql
-- Team / squad system.
-- Anyone can create a team (they become leader).
-- Only admins can mark a team as official.
-- Users can apply to join; the leader approves or rejects.

-- ── teams ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.teams (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  description  text,
  logo_url     text,
  banner_url   text,
  is_official  boolean NOT NULL DEFAULT false,
  leader_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_by   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teams_select"        ON public.teams;
DROP POLICY IF EXISTS "teams_insert"        ON public.teams;
DROP POLICY IF EXISTS "teams_update_leader" ON public.teams;
DROP POLICY IF EXISTS "teams_delete_leader" ON public.teams;

-- Anyone authenticated can view teams.
CREATE POLICY "teams_select" ON public.teams
  FOR SELECT USING (true);

-- Any authenticated user can create a team (they supply their own id as leader).
CREATE POLICY "teams_insert" ON public.teams
  FOR INSERT WITH CHECK (auth.uid() = created_by AND auth.uid() = leader_id);

-- Only the leader can update (except is_official — handled via admin RPC).
CREATE POLICY "teams_update_leader" ON public.teams
  FOR UPDATE USING (auth.uid() = leader_id)
  WITH CHECK (auth.uid() = leader_id AND is_official = (SELECT is_official FROM public.teams WHERE id = teams.id));

-- Only the leader can delete their own team.
CREATE POLICY "teams_delete_leader" ON public.teams
  FOR DELETE USING (auth.uid() = leader_id);

-- ── team_members ──────────────────────────────────────────────────────────────
-- role:   'leader' | 'member'
-- status: 'pending' (applied, awaiting approval) | 'active' (approved)
CREATE TABLE IF NOT EXISTS public.team_members (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id    uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role       text NOT NULL DEFAULT 'member' CHECK (role IN ('leader', 'member')),
  status     text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active')),
  joined_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (team_id, user_id)
);

ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "team_members_select"         ON public.team_members;
DROP POLICY IF EXISTS "team_members_apply"          ON public.team_members;
DROP POLICY IF EXISTS "team_members_leader_manage"  ON public.team_members;
DROP POLICY IF EXISTS "team_members_self_leave"     ON public.team_members;

CREATE POLICY "team_members_select" ON public.team_members
  FOR SELECT USING (true);

-- Users can insert their own membership (= apply to join).
CREATE POLICY "team_members_apply" ON public.team_members
  FOR INSERT WITH CHECK (auth.uid() = user_id AND role = 'member' AND status = 'pending');

-- The team leader can update any member's status/role.
CREATE POLICY "team_members_leader_manage" ON public.team_members
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.teams t
       WHERE t.id = team_id AND t.leader_id = auth.uid()
    )
  );

-- Members can delete their own row (leave team).
CREATE POLICY "team_members_self_leave" ON public.team_members
  FOR DELETE USING (auth.uid() = user_id);

-- ── admin RPC: set_team_official ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_team_official(p_team_id uuid, p_official boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only admins may call this.
  IF NOT EXISTS (SELECT 1 FROM public.admin_roles WHERE user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Forbidden: admins only';
  END IF;
  UPDATE public.teams SET is_official = p_official, updated_at = now()
   WHERE id = p_team_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_team_official(uuid, boolean) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.set_team_official(uuid, boolean) FROM anon;

-- Seed the leader as an active member when a team is created.
CREATE OR REPLACE FUNCTION public.auto_add_leader_as_member()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.team_members(team_id, user_id, role, status)
  VALUES (NEW.id, NEW.leader_id, 'leader', 'active')
  ON CONFLICT (team_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_add_leader ON public.teams;
CREATE TRIGGER trg_auto_add_leader
  AFTER INSERT ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.auto_add_leader_as_member();
