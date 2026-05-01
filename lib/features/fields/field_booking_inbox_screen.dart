import 'package:flutter/material.dart';

import '../../shared/widgets/persistent_shell_bottom_nav.dart';
import 'field_model.dart';
import 'field_repository.dart';

class FieldBookingInboxScreen extends StatefulWidget {
  const FieldBookingInboxScreen({
    super.key,
    required this.field,
  });

  final FieldModel field;

  @override
  State<FieldBookingInboxScreen> createState() => _FieldBookingInboxScreenState();
}

class _FieldBookingInboxScreenState extends State<FieldBookingInboxScreen> {
  final FieldRepository _repository = FieldRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<FieldBookingRequestModel>> _future;
  bool _updating = false;
  String _statusFilter = 'all';
  String _sortBy = 'pending_first';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _future = _repository.getBookingsForField(widget.field.id);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = _repository.getBookingsForField(widget.field.id);
    });
    await _future;
  }

  Future<void> _setStatus(FieldBookingRequestModel booking, String status) async {
    if (_updating) {
      return;
    }
    setState(() {
      _updating = true;
    });

    try {
      await _repository.updateBookingStatus(bookingId: booking.id, status: status);
      if (!mounted) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking marked as $status.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update booking: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  String _formatOptions(FieldBookingRequestModel booking) {
    if (booking.selectedOptions.isEmpty) {
      return 'No extras selected';
    }

    return booking.selectedOptions.map((Map<String, dynamic> option) {
      final String label = (option['label'] ?? '').toString().trim();
      final int? price = (option['price_yen'] as num?)?.toInt();
      if (label.isEmpty) {
        return 'Option';
      }
      return price == null ? label : '$label (+¥$price)';
    }).join(', ');
  }

  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dateRange = picked;
    });
  }

  List<FieldBookingRequestModel> _applyFilters(
    List<FieldBookingRequestModel> source,
  ) {
    List<FieldBookingRequestModel> filtered = List<FieldBookingRequestModel>.from(
      source,
    );

    final String query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((FieldBookingRequestModel booking) {
        return booking.bookingName.toLowerCase().contains(query) ||
            booking.bookingEmail.toLowerCase().contains(query);
      }).toList();
    }

    if (_statusFilter != 'all') {
      filtered = filtered.where((FieldBookingRequestModel booking) {
        return booking.status.toLowerCase() == _statusFilter;
      }).toList();
    }

    if (_dateRange != null) {
      final DateTime start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final DateTime end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
      );
      filtered = filtered.where((FieldBookingRequestModel booking) {
        return !booking.createdAt.isBefore(start) && !booking.createdAt.isAfter(end);
      }).toList();
    }

    if (_sortBy == 'newest') {
      filtered.sort((FieldBookingRequestModel a, FieldBookingRequestModel b) {
        return b.createdAt.compareTo(a.createdAt);
      });
    } else if (_sortBy == 'oldest') {
      filtered.sort((FieldBookingRequestModel a, FieldBookingRequestModel b) {
        return a.createdAt.compareTo(b.createdAt);
      });
    } else {
      filtered.sort((FieldBookingRequestModel a, FieldBookingRequestModel b) {
        final bool aPending = a.status.toLowerCase() == 'pending';
        final bool bPending = b.status.toLowerCase() == 'pending';
        if (aPending != bPending) {
          return aPending ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.field.name} bookings'),
      ),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<FieldBookingRequestModel>>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<List<FieldBookingRequestModel>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: <Widget>[
                  const SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load bookings: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            final List<FieldBookingRequestModel> allBookings = snapshot.data ??
                const <FieldBookingRequestModel>[];
            final List<FieldBookingRequestModel> bookings = _applyFilters(
              allBookings,
            );

            final List<Widget> children = <Widget>[
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Search by name or email',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _statusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(value: 'all', child: Text('All')),
                              DropdownMenuItem(
                                value: 'pending',
                                child: Text('Pending'),
                              ),
                              DropdownMenuItem(
                                value: 'confirmed',
                                child: Text('Confirmed'),
                              ),
                              DropdownMenuItem(
                                value: 'cancelled',
                                child: Text('Cancelled'),
                              ),
                            ],
                            onChanged: (String? value) {
                              setState(() {
                                _statusFilter = value ?? 'all';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _sortBy,
                            decoration: const InputDecoration(labelText: 'Sort'),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(
                                value: 'pending_first',
                                child: Text('Pending first'),
                              ),
                              DropdownMenuItem(
                                value: 'newest',
                                child: Text('Newest first'),
                              ),
                              DropdownMenuItem(
                                value: 'oldest',
                                child: Text('Oldest first'),
                              ),
                            ],
                            onChanged: (String? value) {
                              setState(() {
                                _sortBy = value ?? 'pending_first';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _dateRange == null
                                ? 'Any date'
                                : 'From ${_dateRange!.start.toLocal().toString().split(' ').first} to ${_dateRange!.end.toLocal().toString().split(' ').first}',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickDateRange,
                          icon: const Icon(Icons.date_range_outlined),
                          label: const Text('Date range'),
                        ),
                        if (_dateRange != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _dateRange = null;
                              });
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ];

            if (bookings.isEmpty) {
              children.add(
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: Text('No bookings match your filters.')),
                ),
              );
              return ListView(children: children);
            }

            children.addAll(bookings.map((FieldBookingRequestModel booking) {
              final String status = booking.status.trim().toLowerCase();
              final bool isPending = status == 'pending';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                booking.bookingName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'confirmed'
                                    ? Colors.green.withAlpha(32)
                                    : status == 'cancelled'
                                        ? Colors.red.withAlpha(32)
                                        : Colors.orange.withAlpha(32),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Phone: ${booking.bookingPhone}'),
                        Text('Email: ${booking.bookingEmail}'),
                        const SizedBox(height: 6),
                        Text('Message: ${booking.message}'),
                        const SizedBox(height: 6),
                        Text(
                          'Extras: ${_formatOptions(booking)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Requested: ${booking.createdAt}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        if (isPending)
                          Row(
                            children: <Widget>[
                              FilledButton.tonalIcon(
                                onPressed: _updating
                                    ? null
                                    : () => _setStatus(booking, 'cancelled'),
                                icon: const Icon(Icons.close),
                                label: const Text('Decline'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _updating
                                    ? null
                                    : () => _setStatus(booking, 'confirmed'),
                                icon: const Icon(Icons.check),
                                label: const Text('Confirm'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
            }).toList());

            return ListView(children: children);
          },
        ),
      ),
    );
  }
}
