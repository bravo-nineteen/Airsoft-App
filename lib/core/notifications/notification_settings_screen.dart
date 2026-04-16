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
              ? Center(child: Text(l10n.t('noNotificationSettingsFound')))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_isSaving)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),
                    SwitchListTile.adaptive(
                      title: Text(l10n.t('newEventsLabel')),
                      subtitle: Text(l10n.t('newEventsSubtitle')),
                      value: prefs.eventNotifications,
                      onChanged: (value) {
                        _save(prefs.copyWith(eventNotifications: value));
                      },
                    ),
                    SwitchListTile.adaptive(
                      title: Text(l10n.t('meetupActivity')),
                      subtitle: Text(l10n.t('meetupActivitySubtitle')),
                      value: prefs.meetupNotifications,
                      onChanged: (value) {
                        _save(prefs.copyWith(meetupNotifications: value));
                      },
                    ),
                    SwitchListTile.adaptive(
                      title: Text(l10n.t('directMessages')),
                      subtitle: Text(l10n.t('directMessagesSubtitle')),
                      value: prefs.directMessageNotifications,
                      onChanged: (value) {
                        _save(
                          prefs.copyWith(directMessageNotifications: value),
                        );
                      },
                    ),
                    SwitchListTile.adaptive(
                      title: Text(l10n.t('fieldUpdates')),
                      subtitle: Text(l10n.t('fieldUpdatesSubtitle')),
                      value: prefs.fieldUpdateNotifications,
                      onChanged: (value) {
                        _save(prefs.copyWith(fieldUpdateNotifications: value));
                      },
                    ),
                  ],
                ),
    );
  }
}
