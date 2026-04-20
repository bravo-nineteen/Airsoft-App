import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'notification_preferences_model.dart';
import 'notification_repository.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationRepository _repository = NotificationRepository();

  NotificationPreferencesModel? _preferences;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await _repository.getOrCreatePreferences();
      if (!mounted) return;

      setState(() {
        _preferences = prefs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedLoadNotificationSettings', args: {'error': '$e'}),
          ),
        ),
      );
    }
  }

  Future<void> _save(NotificationPreferencesModel updated) async {
    setState(() {
      _isSaving = true;
      _preferences = updated;
    });

    try {
      final saved = await _repository.updatePreferences(updated);
      if (!mounted) return;

      setState(() {
        _preferences = saved;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedSaveNotificationSettings', args: {'error': '$e'}),
          ),
        ),
      );
    }
  }

  Future<void> _updateMaster(bool enabled) async {
    final prefs = _preferences;
    if (prefs == null) return;

    await _save(
      prefs.copyWith(
        eventNotifications: enabled,
        meetupNotifications: enabled,
        directMessageNotifications: enabled,
        fieldUpdateNotifications: enabled,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildNotificationTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return SwitchListTile.adaptive(
      secondary: Icon(
        icon,
        color: enabled ? colorScheme.secondary : Colors.grey,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: enabled ? onChanged : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = _preferences;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('notifications')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : prefs == null
              ? Center(
                  child: Text(l10n.t('noNotificationSettingsFound')),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_isSaving)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),
                    Text(
                      l10n.t('notifications'),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose which alerts you want to receive. Disable all notifications at once or control each type individually.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle(context, 'General'),
                    _buildSettingsCard(
                      context: context,
                      children: [
                        SwitchListTile.adaptive(
                          secondary: const Icon(Icons.notifications_active_outlined),
                          title: const Text('Enable notifications'),
                          subtitle: const Text(
                            'Turn all app notifications on or off.',
                          ),
                          value: prefs.eventNotifications ||
                              prefs.meetupNotifications ||
                              prefs.directMessageNotifications ||
                              prefs.fieldUpdateNotifications,
                          onChanged: _isSaving ? null : _updateMaster,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle(context, 'Notification types'),
                    _buildSettingsCard(
                      context: context,
                      children: [
                        _buildNotificationTile(
                          context: context,
                          icon: Icons.event_outlined,
                          title: l10n.t('newEventsLabel'),
                          subtitle: l10n.t('newEventsSubtitle'),
                          value: prefs.eventNotifications,
                          enabled: !_isSaving,
                          onChanged: (value) {
                            _save(
                              prefs.copyWith(eventNotifications: value),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _buildNotificationTile(
                          context: context,
                          icon: Icons.groups_outlined,
                          title: l10n.t('meetupActivity'),
                          subtitle: l10n.t('meetupActivitySubtitle'),
                          value: prefs.meetupNotifications,
                          enabled: !_isSaving,
                          onChanged: (value) {
                            _save(
                              prefs.copyWith(meetupNotifications: value),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _buildNotificationTile(
                          context: context,
                          icon: Icons.chat_bubble_outline,
                          title: l10n.t('directMessages'),
                          subtitle: l10n.t('directMessagesSubtitle'),
                          value: prefs.directMessageNotifications,
                          enabled: !_isSaving,
                          onChanged: (value) {
                            _save(
                              prefs.copyWith(
                                directMessageNotifications: value,
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _buildNotificationTile(
                          context: context,
                          icon: Icons.map_outlined,
                          title: l10n.t('fieldUpdates'),
                          subtitle: l10n.t('fieldUpdatesSubtitle'),
                          value: prefs.fieldUpdateNotifications,
                          enabled: !_isSaving,
                          onChanged: (value) {
                            _save(
                              prefs.copyWith(
                                fieldUpdateNotifications: value,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
