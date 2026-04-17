import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'event_repository.dart';

class EventCreateScreen extends StatefulWidget {
  const EventCreateScreen({super.key});

  @override
  State<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends State<EventCreateScreen> {
  final EventRepository _repository = EventRepository();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _prefectureController = TextEditingController();
  final TextEditingController _organizerController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _maxPlayersController = TextEditingController();

  DateTime _startAt = DateTime.now().add(const Duration(days: 7));
  DateTime _endAt = DateTime.now().add(const Duration(days: 7, hours: 6));

  String _eventType = 'Skirmish';
  String _language = 'English / Japanese';
  String _skillLevel = 'All Levels';

  bool _isSaving = false;

  static const List<String> _eventTypes = <String>[
    'Skirmish',
    'Milsim',
    'Training',
    'Meetup',
    'Game Day',
    'Competition',
  ];

  static const List<String> _languages = <String>[
    'English / Japanese',
    'English',
    'Japanese',
  ];

  static const List<String> _skillLevels = <String>[
    'All Levels',
    'Beginner Friendly',
    'Intermediate',
    'Experienced Only',
  ];

  Future<void> _pickStartDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (pickedTime == null) {
      return;
    }

    final DateTime newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _startAt = newStart;
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(hours: 6));
      }
    });
  }

  Future<void> _pickEndDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _endAt,
      firstDate: _startAt,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endAt),
    );
    if (pickedTime == null) {
      return;
    }

    final DateTime newEnd = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!newEnd.isAfter(_startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('endAfterStart'))),
      );
      return;
    }

    setState(() {
      _endAt = newEnd;
    });
  }

  Future<void> _save() async {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('titleRequired'))),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('descriptionRequired')),
        ),
      );
      return;
    }

    final int? priceYen = int.tryParse(_priceController.text.trim());
    final int? maxPlayers = int.tryParse(_maxPlayersController.text.trim());

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.createEvent(
        title: title,
        description: description,
        startsAt: _startAt,
        endsAt: _endAt,
        location: _locationController.text.trim(),
        prefecture: _prefectureController.text.trim(),
        eventType: _eventType,
        language: _language,
        skillLevel: _skillLevel,
        organizerName: _organizerController.text.trim(),
        contactInfo: _contactController.text.trim(),
        notes: _notesController.text.trim(),
        priceYen: priceYen,
        maxPlayers: maxPlayers,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedCreateEvent', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime value) {
    final String yyyy = value.year.toString().padLeft(4, '0');
    final String mm = value.month.toString().padLeft(2, '0');
    final String dd = value.day.toString().padLeft(2, '0');
    final String hh = value.hour.toString().padLeft(2, '0');
    final String min = value.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _prefectureController.dispose();
    _organizerController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    _priceController.dispose();
    _maxPlayersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('createEvent'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: l10n.title),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _eventType,
              items: _eventTypes
                  .map(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() => _eventType = value);
              },
              decoration: InputDecoration(labelText: l10n.t('eventType')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _language,
              items: _languages
                  .map(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() => _language = value);
              },
              decoration: InputDecoration(labelText: l10n.language),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _skillLevel,
              items: _skillLevels
                  .map(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() => _skillLevel = value);
              },
              decoration: InputDecoration(labelText: l10n.t('skillLevel')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(labelText: l10n.t('locationField')),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prefectureController,
              decoration: InputDecoration(labelText: l10n.t('prefecture')),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.t('start')),
              subtitle: Text(_formatDateTime(_startAt)),
              trailing: OutlinedButton(
                onPressed: _pickStartDateTime,
                child: Text(l10n.t('change')),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.t('end')),
              subtitle: Text(_formatDateTime(_endAt)),
              trailing: OutlinedButton(
                onPressed: _pickEndDateTime,
                child: Text(l10n.t('change')),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.t('priceJpy')),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxPlayersController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.t('maxPlayers')),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _organizerController,
              decoration: InputDecoration(labelText: l10n.t('organizer')),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactController,
              decoration: InputDecoration(labelText: l10n.t('contact')),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 5,
              maxLines: 8,
              decoration: InputDecoration(labelText: l10n.t('description')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(labelText: l10n.t('rules')),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Create Event'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
