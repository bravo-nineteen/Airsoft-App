import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_settings_screen.dart';
import 'display_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _tile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // ===== DISPLAY =====
          _sectionTitle('Display'),
          _tile(
            context: context,
            icon: Icons.palette_outlined,
            title: 'Display Settings',
            onTap: () => _navigate(context, const DisplaySettingsScreen()),
          ),

          // ===== NOTIFICATIONS =====
          _sectionTitle('Notifications'),
          _tile(
            context: context,
            icon: Icons.notifications_outlined,
            title: 'Notification Settings',
            onTap: () =>
                _navigate(context, const NotificationSettingsScreen()),
          ),

          // ===== PRIVACY =====
          _sectionTitle('Privacy'),
          _tile(
            context: context,
            icon: Icons.lock_outline,
            title: 'Privacy Settings',
            onTap: () =>
                _navigate(context, const PrivacySettingsScreen()),
          ),

          // ===== ACCOUNT =====
          _sectionTitle('Account'),
          _tile(
            context: context,
            icon: Icons.person_outline,
            title: 'Account Settings',
            onTap: () =>
                _navigate(context, const AccountSettingsScreen()),
          ),

          const SizedBox(height: 30),

          // ===== LOGOUT =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
