import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/app_localizations.dart';
import '../../core/ads/ad_access_repository.dart';
import '../../core/ads/ad_config.dart';
import '../../shared/widgets/ad_inline_banner.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../core/content/app_content_preloader.dart';
import 'event_create_screen.dart';
import 'event_details_screen.dart';
import 'event_model.dart';
import 'event_repository.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final AppContentPreloader _contentPreloader = AppContentPreloader.instance;
  final EventRepository _repository = EventRepository();
  final AdAccessRepository _adAccessRepository = AdAccessRepository();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<EventModel>> _future;
  List<EventModel> _cachedEvents = <EventModel>[];
  Timer? _backgroundSyncTimer;
  String _searchQuery = '';
  String? _selectedEventType;
  String? _selectedLanguage;
  String? _selectedSkillLevel;
  bool _showAds = false;

  @override
  void initState() {
    super.initState();
    _cachedEvents = _contentPreloader.events;
    _contentPreloader.eventsRevision.addListener(_handleSharedEventsUpdated);
    _future = _contentPreloader.loadEvents();
    _loadAdVisibility();
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted) {
        return;
      }
      _refresh();
    });
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = _contentPreloader.refreshEvents();
    });
    await _future;
  }

  void _handleSharedEventsUpdated() {
    if (!mounted) {
      return;
    }

    setState(() {
      _cachedEvents = _contentPreloader.events;
      _future = Future<List<EventModel>>.value(_cachedEvents);
    });
  }

  Future<void> _openCreate() async {
    final bool? created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EventCreateScreen()));

    if (!mounted) {
      return;
    }

    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _openEdit(EventModel event) async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventCreateScreen(
          existingEvent: event,
          isOfficial: event.isOfficial,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await _refresh();
    }
  }

  Future<void> _deleteEvent(EventModel event) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('deleteEventPromptTitle')),
          content: Text(
            l10n.t('deleteEventPromptBody', args: {'title': event.title}),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('deleteEventAction')),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _repository.deleteEvent(event.id);
      if (!mounted) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('deletedEvent', args: {'title': event.title})),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('failedDeleteEvent', args: {'error': '$error'})),
        ),
      );
    }
  }

  bool _matchesEventSearch(EventModel event) {
    final String query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _matchesStructuredFilters(event);
    }

    final String haystack = <String>[
      event.title,
      event.description,
      event.language ?? '',
      event.location ?? '',
      event.prefecture ?? '',
      event.eventType ?? '',
      event.skillLevel ?? '',
      event.organizerName ?? '',
    ].join(' ').toLowerCase();

    return haystack.contains(query) && _matchesStructuredFilters(event);
  }

  bool _matchesStructuredFilters(EventModel event) {
    if (_selectedEventType != null && event.eventType != _selectedEventType) {
      return false;
    }
    if (_selectedLanguage != null && event.language != _selectedLanguage) {
      return false;
    }
    if (_selectedSkillLevel != null &&
        event.skillLevel != _selectedSkillLevel) {
      return false;
    }
    return true;
  }

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        _selectedEventType != null ||
        _selectedLanguage != null ||
        _selectedSkillLevel != null;
  }

  List<String> _optionsFor(
    List<EventModel> events,
    String? Function(EventModel event) selector,
  ) {
    final Set<String> values = events
        .map(selector)
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final List<String> sorted = values.toList()..sort();
    return sorted;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedEventType = null;
      _selectedLanguage = null;
      _selectedSkillLevel = null;
    });
  }

  Widget _buildSearchAndFilters(
    AppLocalizations l10n,
    List<EventModel> events,
  ) {
    final List<String> eventTypes = _optionsFor(
      events,
      (EventModel event) => event.eventType,
    );
    final List<String> languages = _optionsFor(
      events,
      (EventModel event) => event.language,
    );
    final List<String> skillLevels = _optionsFor(
      events,
      (EventModel event) => event.skillLevel,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _searchController,
          onChanged: (String value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: l10n.t('eventSearchHint'),
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _FilterDropdown(
              label: l10n.t('eventType'),
              value: _selectedEventType,
              options: eventTypes,
              onChanged: (String? value) {
                setState(() {
                  _selectedEventType = value;
                });
              },
            ),
            _FilterDropdown(
              label: l10n.language,
              value: _selectedLanguage,
              options: languages,
              onChanged: (String? value) {
                setState(() {
                  _selectedLanguage = value;
                });
              },
            ),
            _FilterDropdown(
              label: l10n.t('skillLevel'),
              value: _selectedSkillLevel,
              options: skillLevels,
              onChanged: (String? value) {
                setState(() {
                  _selectedSkillLevel = value;
                });
              },
            ),
          ],
        ),
        if (_hasActiveFilters) ...<Widget>[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: Text(l10n.t('clearFilters')),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _loadAdVisibility() async {
    if (!AdConfig.isConfigured) {
      if (mounted) {
        setState(() {
          _showAds = false;
        });
      }
      return;
    }

    try {
      final bool showAds = await _adAccessRepository.shouldShowAds();
      if (!mounted) {
        return;
      }
      setState(() {
        _showAds = showAds;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _showAds = AdConfig.isConfigured;
        });
      }
    }
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _contentPreloader.eventsRevision.removeListener(_handleSharedEventsUpdated);
    _searchController.dispose();
    super.dispose();
  }

  String? _statusLabel(AppLocalizations l10n, EventModel event) {
    switch (event.currentUserAttendanceStatus) {
      case 'attending':
        return l10n.t('attendanceAttending');
      case 'interested':
        return 'Interested';
      case 'cancelled':
        return l10n.t('attendanceCancelled');
      case 'attended':
        return l10n.t('attendanceAttended');
      case 'no_show':
        return l10n.t('attendanceNoShow');
      default:
        return null;
    }
  }

  Future<void> _openBookTickets(BuildContext context, String url) async {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<EventModel>>(
            future: _future,
            initialData: _cachedEvents,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<EventModel>> snapshot,
                ) {
                  final List<EventModel> events =
                      snapshot.data ?? _cachedEvents;
                  if (snapshot.hasData) {
                    _cachedEvents = snapshot.data!;
                  }

                  if (snapshot.connectionState != ConnectionState.done &&
                      events.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      children: <Widget>[
                        const SizedBox(height: 140),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.t(
                                'failedLoadEvents',
                                args: {'error': '${snapshot.error}'},
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final List<EventModel> filteredEvents = events
                      .where(_matchesEventSearch)
                      .toList();

                  if (events.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.event_outlined,
                      title: 'No events yet',
                      subtitle: 'Check back soon for upcoming airsoft events.',
                    );
                  }

                  if (filteredEvents.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: <Widget>[
                        _buildSearchAndFilters(l10n, events),
                        const SizedBox(height: 18),
                        const EmptyStateWidget(
                          icon: Icons.search_off_outlined,
                          title: 'No matching events',
                          subtitle: 'Try adjusting your search or filters.',
                        ),
                      ],
                    );
                  }

                  final String? currentUserId =
                      Supabase.instance.client.auth.currentUser?.id;

                  final List<Object> feedItems = <Object>[];
                  for (int i = 0; i < filteredEvents.length; i++) {
                    feedItems.add(filteredEvents[i]);
                    if (_showAds &&
                        (i + 1) % AdConfig.feedAdFrequency == 0 &&
                        i != filteredEvents.length - 1) {
                      feedItems.add(const _EventAdSlot());
                    }
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: feedItems.length + 2,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return snapshot.connectionState ==
                                ConnectionState.waiting
                            ? const LinearProgressIndicator(minHeight: 2)
                            : const SizedBox.shrink();
                      }

                      if (index == 1) {
                        return _buildSearchAndFilters(l10n, events);
                      }

                      final Object entry = feedItems[index - 2];
                      if (entry is _EventAdSlot) {
                        return const AdInlineBanner();
                      }

                      final EventModel event = entry as EventModel;
                      final String? statusLabel = _statusLabel(l10n, event);
                      final bool canEdit =
                          currentUserId != null &&
                          event.hostUserId == currentUserId;

                      return _EventCard(
                        event: event,
                        l10n: l10n,
                        statusLabel: statusLabel,
                        canEdit: canEdit,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EventDetailsScreen(event: event),
                            ),
                          );
                          if (!mounted) {
                            return;
                          }
                          await _refresh();
                        },
                        onBookTickets:
                            (event.bookTicketsUrl ?? '').trim().isNotEmpty
                                ? () => _openBookTickets(
                                    context, event.bookTicketsUrl!)
                                : null,
                        onEdit: () => _openEdit(event),
                        onDelete: () => _deleteEvent(event),
                      );
                    },
                  );
                },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.t('newEventCta')),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.l10n,
    required this.statusLabel,
    required this.canEdit,
    required this.onTap,
    required this.onBookTickets,
    required this.onEdit,
    required this.onDelete,
  });

  final EventModel event;
  final AppLocalizations l10n;
  final String? statusLabel;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onBookTickets;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static String _monthAbbr(int month) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String imageUrl = (event.imageUrl ?? '').trim();
    final bool hasImage = imageUrl.isNotEmpty;
    final DateTime dt = event.startsAt;
    final String day = dt.day.toString();
    final String month = _monthAbbr(dt.month);
    final String skillLabel = (event.skillLevel ?? 'All Levels').trim();
    final String skillNorm = skillLabel.toLowerCase();
    final Color skillColor = skillNorm.contains('beginner')
        ? Colors.green
        : skillNorm.contains('intermediate')
            ? Colors.orange
            : skillNorm.contains('experienced')
                ? Colors.red
                : theme.colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (event.isOfficial)
              Container(
                width: double.infinity,
                color: theme.colorScheme.secondaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.verified,
                      size: 14,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Official Event',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            if (hasImage)
              AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 54,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          day,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onPrimaryContainer,
                            height: 1,
                          ),
                        ),
                        Text(
                          month,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if ((event.location ?? '').trim().isNotEmpty)
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.place_outlined,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  event.location!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            _EventPill(label: skillLabel, color: skillColor),
                            if ((event.eventType ?? '').trim().isNotEmpty)
                              _EventPill(
                                label: event.eventType!.trim(),
                                color: theme.colorScheme.secondary,
                              ),
                            if (statusLabel != null)
                              _EventPill(label: statusLabel!, color: Colors.green),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.people_outline,
                              size: 14,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.t(
                                'goingWithCount',
                                args: {'count': '${event.attendingCount}'},
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l10n.t(
                                'attendedWithCount',
                                args: {'count': '${event.attendedCount}'},
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  if ((event.bookTicketsUrl ?? '').trim().isNotEmpty)
                    TextButton.icon(
                      onPressed: onBookTickets,
                      icon: const Icon(
                        Icons.confirmation_number_outlined,
                        size: 16,
                      ),
                      label: const Text('Book tickets'),
                    ),
                  const Spacer(),
                  if (canEdit)
                    PopupMenuButton<String>(
                      tooltip: l10n.t('manageEvent'),
                      onSelected: (String value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text(l10n.t('editEvent')),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text(l10n.t('deleteEventAction')),
                            ),
                          ],
                      icon: const Icon(Icons.more_vert),
                    ),
                  const Icon(Icons.chevron_right),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventPill extends StatelessWidget {
  const _EventPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(36),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EventAdSlot {
  const _EventAdSlot();
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 240),
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(
            value: null,
            child: Text(AppLocalizations.of(context).t('all')),
          ),
          ...options.map(
            (String option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
