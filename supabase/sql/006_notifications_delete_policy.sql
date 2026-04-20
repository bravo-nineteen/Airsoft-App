-- Allow users to delete their own notifications.
-- This fixes client-side delete actions blocked by RLS.

drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own
  on public.notifications
  for delete
  using (auth.uid() = user_id);
