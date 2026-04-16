import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityUserProfileScreen extends StatefulWidget {
  const CommunityUserProfileScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<CommunityUserProfileScreen> createState() =>
      _CommunityUserProfileScreenState();
}

class _CommunityUserProfileScreenState
    extends State<CommunityUserProfileScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = response == null ? null : Map<String, dynamic>.from(response);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _infoTile(String label, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(text),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final avatarUrl = profile?['avatar_url']?.toString();
    final callSign = (profile?['call_sign'] ?? 'Unknown').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? const Center(child: Text('Profile not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Center(
                      child: CircleAvatar(
                        radius: 46,
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                                callSign.isEmpty ? '?' : callSign.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontSize: 24),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        callSign,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _infoTile('User code', profile['user_code']?.toString()),
                    _infoTile('Area', profile['area']?.toString()),
                    _infoTile('Team', profile['team_name']?.toString()),
                    _infoTile('Loadout', profile['loadout']?.toString()),
                    _infoTile('Instagram', profile['instagram']?.toString()),
                    _infoTile('Facebook', profile['facebook']?.toString()),
                    _infoTile('YouTube', profile['youtube']?.toString()),
                  ],
                ),
    );
  }
}