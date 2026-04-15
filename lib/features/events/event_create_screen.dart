import 'package:flutter/material.dart';

import 'event_repository.dart';

class EventCreateScreen extends StatefulWidget {
  const EventCreateScreen({super.key});

  @override
  State<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends State<EventCreateScreen> {
  final EventRepository _repository = EventRepository();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _prefectureController = TextEditingController();
  final _organizerController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxPlayersController = TextEditingController();

  DateTime _startAt = DateTime.now().add(const Duration(days: 7));
  DateTime _endAt = DateTime.now().add(const Duration(days: 7, hours: 6));

  String _eventType = 'Skirmish';
  String _language = 'English / Japanese';
  String _skillLevel = 'All Levels';

  bool _isSaving = false;

  static const List<String> _eventTypes = [
    'Skirmish',
    'Milsim',
    'Training',
    'Meetup',
    'Game Day',
    'Competition',
  ];

  static const List<String> _languages = [
    'English / Japanese',
    'English',
    'Japanese',
  ];

  static const List<String> _skillLevels = [
    'All Levels',
    'Beginner Friendly',
    'Intermediate',
    'Experienced Only',
  ];

  Future<void> _pickStartDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (pickedTime == null) return;

    final newStart = DateTime(
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
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endAt,
      firstDate: _startAt,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endAt),
    );
    if (pickedTime == null) return;

    final newEnd = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!newEnd.isAfter(_startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    setState(() {
      _endAt = newEnd;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description is required.')),
      );
      return;
    }

    final priceYen = int.tryParse(_priceController.text.trim());
    final maxPlayers = int.tryParse(_maxPlayersController.text.trim());

    setState(() => _isSaving = true);

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

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create event: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDateTime(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _eventType,
            items: _eventTypes
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _eventType = value);
            },
            decoration: const InputDecoration(labelText: 'Event Type'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _language,
            items: _languages
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _language = value);
            },
            decoration: const InputDecoration(labelText: 'Language'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _skillLevel,
            items: _skillLevels
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _skillLevel = value);
            },
            decoration: const InputDecoration(labelText: 'Skill Level'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Location / Field'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _prefectureController,
            decoration: const InputDecoration(labelText: 'Prefecture'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start'),
            subtitle: Text(_formatDateTime(_startAt)),
            trailing: OutlinedButton(
              onPressed: _pickStartDateTime,
              child: const Text('Change'),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End'),
            subtitle: Text(_formatDateTime(_endAt)),
            trailing: OutlinedButton(
              onPressed: _pickEndDateTime,
              child: const Text('Change'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Price (JPY)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxPlayersController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Max Players'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _organizerController,
            decoration: const InputDecoration(labelText: 'Organizer Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactController,
            decoration: const InputDecoration(
              labelText: 'Contact Info',
              hintText: 'Email, Instagram, LINE, etc.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Rules / Notes',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Save Event'),
          ),
        ],
      ),
    );
  }
}