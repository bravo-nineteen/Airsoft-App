import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile/profile_model.dart';
import '../profile/profile_repository.dart';

/// Shown once after a user's first sign-in when their profile is incomplete.
/// Guides them through setting a call-sign, area, and team name.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  static const String _prefKey = 'onboarding_done';

  /// Returns [true] if this user still needs to see onboarding.
  static Future<bool> needsOnboarding() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('${_prefKey}_${user.id}') == true) return false;

    // Also check if the profile already has a meaningful call sign.
    try {
      final profile =
          await ProfileRepository().getCurrentProfile();
      final callSign = (profile?.callSign ?? '').trim();
      // A profile with a real call sign (not just the email prefix) is
      // considered already set up.
      final email = user.email ?? '';
      final emailPrefix = email.split('@').first.trim();
      final isDefault = callSign.isEmpty ||
          callSign.toLowerCase() == emailPrefix.toLowerCase() ||
          callSign.toLowerCase() == 'operator';
      if (!isDefault) {
        // Profile looks complete — mark as done and skip onboarding.
        await _markDone(user.id);
        return false;
      }
    } catch (_) {
      // If we can't load the profile, skip onboarding to avoid blocking login.
      return false;
    }

    return true;
  }

  static Future<void> _markDone(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefKey}_$userId', true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ProfileRepository _repository = ProfileRepository();
  final TextEditingController _callSignController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  final PageController _pageController = PageController();

  int _currentPage = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _callSignController.dispose();
    _areaController.dispose();
    _teamController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final callSign = _callSignController.text.trim();
    if (callSign.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a call sign.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final current = await _repository.getCurrentProfile();
      if (current == null) return;

      final updated = ProfileModel(
        id: current.id,
        userCode: current.userCode,
        callSign: callSign,
        area: _areaController.text.trim().isEmpty
            ? current.area
            : _areaController.text.trim(),
        teamName: _teamController.text.trim().isEmpty
            ? current.teamName
            : _teamController.text.trim(),
        loadout: current.loadout,
        loadoutCards: current.loadoutCards,
        instagram: current.instagram,
        facebook: current.facebook,
        youtube: current.youtube,
        avatarUrl: current.avatarUrl,
      );

      await _repository.updateCurrentProfile(updated);

      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      await OnboardingScreen._markDone(userId);

      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _save();
    }
  }

  void _skip() {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    OnboardingScreen._markDone(userId);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _isSaving ? null : _skip,
                child: const Text('Skip'),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _OnboardingPage(
                    icon: Icons.military_tech_outlined,
                    title: 'What\'s your call sign?',
                    subtitle:
                        'This is the name other players will see across the app.',
                    child: _buildField(
                      controller: _callSignController,
                      hint: 'e.g. Ghost, Viper, Spectre',
                      autofocus: true,
                    ),
                  ),
                  _OnboardingPage(
                    icon: Icons.location_on_outlined,
                    title: 'Where are you based?',
                    subtitle:
                        'Helps you find local events and players. You can leave this blank.',
                    child: _buildField(
                      controller: _areaController,
                      hint: 'e.g. Tokyo, Osaka, Kanagawa',
                    ),
                  ),
                  _OnboardingPage(
                    icon: Icons.groups_outlined,
                    title: 'Any team?',
                    subtitle:
                        'Let other players know your squad. Totally optional.',
                    child: _buildField(
                      controller: _teamController,
                      hint: 'e.g. Alpha Squad, Ghost Company',
                    ),
                  ),
                ],
              ),
            ),

            // Page dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Next / Finish button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _next,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_currentPage < 2 ? 'Next' : 'Get Started'),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}
