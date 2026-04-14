import 'package:flutter/material.dart';

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
        SnackBar(content: Text('Failed to load notification settings: $e')),
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
        SnackBar(content: Text('Failed to save notification settings: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _preferences;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : prefs == null
              ? const Center(child: Text('No notification settings found.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_isSaving)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),
                    SwitchListTile.adaptive(
                      title: const Text('New Events'),
                      subtitle: const Text('Get notified when new events go live'),
                      value: prefs.eventNotifications,
                      onChanged: (value) {
                        _save(prefs.copyWith(eventNotifications: value));
                      },
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Meetup Activity'),
                      subtitle: const Text('Get notified about meetup updates'),
                      value: prefs.meetupNotifications,
                      onChanged: (value) {
                        _save(prefs.copyWith(meetupNotifications: value));
                      },
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Direct Messages'),
                      subtitle: const Text('Get notified when someone messages you'),
                      value: prefs.directMessageNotifications,
                      onChanged: (value) {
                        _save(
                          prefs.copyWith(directMessageNotifications: value),
                        );
                      },
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Field Updates'),
                      subtitle:
                          const Text('Get notified about field changes and news'),
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
