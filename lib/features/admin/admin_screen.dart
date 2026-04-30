import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_model.dart';
import '../events/event_create_screen.dart';
import '../events/event_model.dart';
import '../fields/field_model.dart';
import '../profile/profile_model.dart';
import '../shops/shop_model.dart';
import 'admin_create_field_screen.dart';
import 'admin_create_shop_screen.dart';
import 'admin_repository.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final AdminRepository _repository = AdminRepository();
  final TextEditingController _userSearchController = TextEditingController();
  late final TabController _tabController = TabController(
    length: 6,
    vsync: this,
  );
  late Future<bool> _isAdminFuture;
  late Future<_AdminDashboardData> _dashboardFuture;
  late Future<List<ProfileModel>> _profilesFuture;
  late Future<List<FieldClaimRequestRecord>> _claimRequestsFuture;
  late Future<List<FieldClaimRequestRecord>> _claimHistoryFuture;
  late Future<List<FieldClaimRequestRecord>> _paymentRequestedClaimsFuture;
  late Future<List<MembershipRequestRecord>> _membershipRequestsFuture;
  late Future<List<MembershipRequestRecord>> _reviewedMembershipFuture;
  late Future<List<SafetyReportRecord>> _safetyReportsFuture;
  late Future<List<ModerationQueueRecord>> _moderationQueueFuture;
  late Future<List<ModerationAuditLogRecord>> _moderationAuditFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _isAdminFuture = _repository.isCurrentUserAdmin();
    _dashboardFuture = _loadDashboard();
    _profilesFuture = _repository.searchProfiles('');
    _claimRequestsFuture = _repository.getPendingFieldClaimRequests();
    _claimHistoryFuture = _repository.getReviewedFieldClaimRequests();
    _paymentRequestedClaimsFuture =
        _repository.getPaymentRequestedFieldClaimRequests();
    _membershipRequestsFuture = _repository.getMembershipRequests();
    _reviewedMembershipFuture = _repository.getReviewedMembershipRequests();
    _safetyReportsFuture = _repository.getSafetyReports(limit: 100);
    _moderationQueueFuture = _repository.getModerationQueue(limit: 100);
    _moderationAuditFuture = _repository.getModerationAuditLogs(limit: 100);
  }

  Widget _buildAccessDenied({Object? error}) {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? 'Not logged in';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.lock_outline, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Admin access is not enabled for this account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Current user id: $currentUserId',
              textAlign: TextAlign.center,
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text('Error: $error', textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isAdminFuture = _repository.isCurrentUserAdmin();
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry check'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_AdminDashboardData> _loadDashboard() async {
    final results = await Future.wait<dynamic>([
      _repository.getRecentPosts(),
      _repository.getRecentComments(),
      _repository.getRecentEvents(),
      _repository.getRecentFields(),
      _repository.getRecentBans(),
      _repository.getRecentShops(),
    ]);

    return _AdminDashboardData(
      posts: results[0] as List<CommunityPostModel>,
      comments: results[1] as List<CommunityCommentModel>,
      events: results[2] as List<EventModel>,
      fields: results[3] as List<FieldModel>,
      bans: results[4] as List<AdminBanRecord>,
      shops: results[5] as List<ShopModel>,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _dashboardFuture = _loadDashboard();
      _profilesFuture = _repository.searchProfiles(_userSearchController.text);
      _claimRequestsFuture = _repository.getPendingFieldClaimRequests();
      _claimHistoryFuture = _repository.getReviewedFieldClaimRequests();
      _paymentRequestedClaimsFuture =
          _repository.getPaymentRequestedFieldClaimRequests();
      _membershipRequestsFuture = _repository.getMembershipRequests();
      _reviewedMembershipFuture = _repository.getReviewedMembershipRequests();
      _safetyReportsFuture = _repository.getSafetyReports(limit: 100);
      _moderationQueueFuture = _repository.getModerationQueue(limit: 100);
      _moderationAuditFuture = _repository.getModerationAuditLogs(limit: 100);
    });
    await Future.wait<dynamic>([
      _dashboardFuture,
      _profilesFuture,
      _claimRequestsFuture,
      _claimHistoryFuture,
      _paymentRequestedClaimsFuture,
      _membershipRequestsFuture,
      _reviewedMembershipFuture,
      _safetyReportsFuture,
      _moderationQueueFuture,
      _moderationAuditFuture,
    ]);
  }

  Future<void> _reviewReport(
    SafetyReportRecord report,
    String status,
  ) async {
    final TextEditingController noteController = TextEditingController();
    final bool? shouldProceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Mark as $status'),
          content: TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Moderator note (optional)'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (shouldProceed != true) {
      noteController.dispose();
      return;
    }

    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.reviewSafetyReport(
        report: report,
        reportStatus: status,
        note: noteController.text,
      );
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Safety review failed: $error')));
    } finally {
      noteController.dispose();
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _assignQueueItem(ModerationQueueRecord item) async {
    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.assignQueueItemToMe(item.id);
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assign failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _changeQueueStatus(ModerationQueueRecord item, String status) async {
    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.updateQueueItemStatus(queueItemId: item.id, status: status);
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Queue update failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Widget _buildTargetPreview(ModerationQueueRecord item) {
    return FutureBuilder<ModerationTargetPreview?>(
      future: _repository.getTargetPreview(
        targetType: item.targetType,
        targetId: item.targetId,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<ModerationTargetPreview?> snapshot,
      ) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        final ModerationTargetPreview? preview = snapshot.data;
        if (preview == null) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Preview unavailable.'),
          );
        }

        final String createdLabel = preview.createdAt == null
            ? '-'
            : preview.createdAt!.toLocal().toString();

        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                preview.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((preview.subtitle ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(preview.subtitle!),
                ),
              if ((preview.body ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    preview.body!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 4),
              Text('Created: $createdLabel'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _searchUsers() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _profilesFuture = _repository.searchProfiles(_userSearchController.text);
    });
    await _profilesFuture;
  }

  Future<void> _confirmDelete({
    required String title,
    required Future<void> Function() onDelete,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete $title?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await onDelete();
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    }
  }

  Future<void> _openIssueBan(ProfileModel profile) async {
    final reasonController = TextEditingController();
    bool isPermanent = false;
    String duration = '7 days';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text('Ban ${profile.displayName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: reasonController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Reason'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Permanent ban'),
                      value: isPermanent,
                      onChanged: (value) {
                        setLocalState(() {
                          isPermanent = value;
                        });
                      },
                    ),
                    if (!isPermanent)
                      DropdownButtonFormField<String>(
                        initialValue: duration,
                        items: const [
                          DropdownMenuItem(
                            value: '1 day',
                            child: Text('1 day'),
                          ),
                          DropdownMenuItem(
                            value: '7 days',
                            child: Text('7 days'),
                          ),
                          DropdownMenuItem(
                            value: '30 days',
                            child: Text('30 days'),
                          ),
                        ],
                        onChanged: (value) {
                          setLocalState(() {
                            duration = value ?? '7 days';
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop({
                    'reason': reasonController.text,
                    'isPermanent': isPermanent,
                    'duration': duration,
                  }),
                  child: const Text('Issue Ban'),
                ),
              ],
            );
          },
        );
      },
    );
    reasonController.dispose();

    if (result == null) {
      return;
    }

    final selectedDuration = result['duration'] as String;
    Duration? durationValue;
    switch (selectedDuration) {
      case '1 day':
        durationValue = const Duration(days: 1);
        break;
      case '30 days':
        durationValue = const Duration(days: 30);
        break;
      case '7 days':
      default:
        durationValue = const Duration(days: 7);
        break;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _repository.issueBan(
        userId: profile.id,
        reason: (result['reason'] as String?) ?? '',
        isPermanent: result['isPermanent'] == true,
        bannedUntil: result['isPermanent'] == true
            ? null
            : DateTime.now().add(durationValue),
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ban failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _revokeBan(AdminBanRecord ban) async {
    try {
      await _repository.revokeBan(ban.id);
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Revoke failed: $error')));
    }
  }

  Future<void> _openOfficialEvent() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const EventCreateScreen(isOfficial: true),
      ),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _openOfficialField() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminCreateFieldScreen()),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _openOfficialShop() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminCreateShopScreen()),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _editEvent(EventModel event) async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventCreateScreen(
          isOfficial: event.isOfficial,
          existingEvent: event,
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

  Future<void> _editField(FieldModel field) async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminCreateFieldScreen(existingField: field),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await _refresh();
    }
  }

  Future<void> _editShop(ShopModel shop) async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminCreateShopScreen(existingShop: shop),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await _refresh();
    }
  }

  Future<void> _requestClaimPayment(FieldClaimRequestRecord request) async {
    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.requestFieldClaimPayment(request.id);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment requested for ${request.staffName}. Contact at ${request.officialEmail}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request payment failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _sendMembershipPaymentRequest(
    MembershipRequestRecord request,
  ) async {
    final TextEditingController noteController = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Send Payment Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a Google Play payment request for ¥${request.annualFeeYen} '
              'to ${request.fullName} (${request.contactEmail})?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Admin note / payment link (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    final String note = noteController.text;
    noteController.dispose();
    if (ok != true) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.sendMembershipPaymentRequest(
        request.id,
        adminNote: note,
      );
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment request sent.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _rejectMembership(MembershipRequestRecord request) async {
    final TextEditingController noteController = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Reject ${request.fullName}\'s membership request?'),
        content: TextField(
          controller: noteController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason / admin note (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final String note = noteController.text;
    noteController.dispose();
    if (ok != true) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.rejectMembershipRequest(request.id, adminNote: note);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership request rejected.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _activateMembership(MembershipRequestRecord request) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Activate membership for ${request.fullName}?'),
        content: const Text(
          'This will grant ad-free access for 1 year. Only confirm after payment has been received.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Activate'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.activateMembership(request.id);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Membership activated for ${request.fullName}. Expires in 1 year.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activation failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _approveClaim(FieldClaimRequestRecord request) async {
    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.approveFieldClaimRequest(request);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approved claim for ${request.staffName}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Approval failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _rejectClaim(FieldClaimRequestRecord request) async {
    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.rejectFieldClaimRequest(request.id);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejected claim for ${request.staffName}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rejection failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Widget _buildModerationTab() {
    return FutureBuilder<_AdminDashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load moderation data: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Recent Posts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...data.posts.map(
              (post) => Card(
                child: ListTile(
                  title: Text(post.title),
                  subtitle: Text(post.authorName),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(
                      title: 'post "${post.title}"',
                      onDelete: () => _repository.deletePost(post.id),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Comments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...data.comments.map(
              (comment) => Card(
                child: ListTile(
                  title: Text(comment.authorName),
                  subtitle: Text(
                    comment.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(
                      title: 'this comment',
                      onDelete: () => _repository.deleteComment(comment.id),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...data.events.map(
              (event) => Card(
                child: ListTile(
                  title: Text(event.title),
                  subtitle: Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(
                      title: 'event "${event.title}"',
                      onDelete: () => _repository.deleteEvent(event.id),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _userSearchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchUsers(),
            decoration: InputDecoration(
              hintText: 'Search users',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _searchUsers,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ProfileModel>>(
            future: _profilesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load users: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final profiles = snapshot.data ?? <ProfileModel>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...profiles.map(
                    (profile) => Card(
                      child: ListTile(
                        title: Text(profile.displayName),
                        subtitle: Text(profile.userCode),
                        trailing: FilledButton(
                          onPressed: _isBusy
                              ? null
                              : () => _openIssueBan(profile),
                          child: const Text('Ban'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<_AdminDashboardData>(
                    future: _dashboardFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Bans',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          ...snapshot.data!.bans.map(
                            (ban) => Card(
                              child: ListTile(
                                title: Text(ban.userId),
                                subtitle: Text(
                                  ban.isPermanent
                                      ? 'Permanent'
                                      : 'Until ${ban.bannedUntil?.toLocal()}',
                                ),
                                trailing: ban.isRevoked
                                    ? const Text('Revoked')
                                    : TextButton(
                                        onPressed: () => _revokeBan(ban),
                                        child: const Text('Revoke'),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOfficialTab() {
    return FutureBuilder<_AdminDashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load official content: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_available),
                title: const Text('Create Official Event'),
                subtitle: const Text('Publish an admin-managed event listing.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openOfficialEvent,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.terrain),
                title: const Text('Create Official Field Listing'),
                subtitle: const Text(
                  'Add an official field entry to the directory.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openOfficialField,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront),
                title: const Text('Create Official Shop Listing'),
                subtitle: const Text(
                  'Add an official shop entry to the directory.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openOfficialShop,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...data.events.map(
              (event) => Card(
                child: ListTile(
                  leading: event.isOfficial
                      ? const Icon(Icons.verified, color: Colors.blue)
                      : const Icon(Icons.event),
                  title: Text(event.title),
                  subtitle: Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editEvent(event),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Fields',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...data.fields.map(
              (field) => Card(
                child: ListTile(
                  leading: field.isOfficial
                      ? const Icon(Icons.verified, color: Colors.blue)
                      : const Icon(Icons.terrain),
                  title: Text(field.name),
                  subtitle: Text(
                    field.fullLocation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editField(field),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Shops',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...data.shops.map(
              (shop) => Card(
                child: ListTile(
                  leading: shop.isOfficial
                      ? const Icon(Icons.verified, color: Colors.blue)
                      : const Icon(Icons.storefront),
                  title: Text(shop.name),
                  subtitle: Text(
                    shop.locationDisplay,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editShop(shop),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClaimsTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<List<FieldClaimRequestRecord>>([
        _claimRequestsFuture,
        _paymentRequestedClaimsFuture,
        _claimHistoryFuture,
      ]),
      builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load claim requests: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<dynamic> packed = snapshot.data ?? <dynamic>[];
        final List<FieldClaimRequestRecord> requests = packed.isNotEmpty
            ? (packed[0] as List<FieldClaimRequestRecord>)
            : <FieldClaimRequestRecord>[];
        final List<FieldClaimRequestRecord> paymentPending = packed.length > 1
            ? (packed[1] as List<FieldClaimRequestRecord>)
            : <FieldClaimRequestRecord>[];
        final List<FieldClaimRequestRecord> history = packed.length > 2
            ? (packed[2] as List<FieldClaimRequestRecord>)
            : <FieldClaimRequestRecord>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Pending Claims', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (requests.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No pending field claims.'),
                ),
              )
            else
              ...requests.map((FieldClaimRequestRecord request) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          (request.fieldName ?? '').trim().isEmpty
                              ? 'Field ${request.fieldId}'
                              : request.fieldName!,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Staff: ${request.staffName}'),
                        Text('ID: ${request.officialIdNumber}'),
                        Text('Phone: ${request.officialPhone}'),
                        Text('Email: ${request.officialEmail}'),
                        Text('Requested by user: ${request.requesterUserId}'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.tonalIcon(
                              onPressed:
                                  _isBusy ? null : () => _rejectClaim(request),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                            ),
                            FilledButton.icon(
                              onPressed: _isBusy
                                  ? null
                                  : () => _requestClaimPayment(request),
                              icon: const Icon(Icons.payment_outlined),
                              label: const Text('Request Payment'),
                            ),
                            FilledButton.icon(
                              onPressed:
                                  _isBusy ? null : () => _approveClaim(request),
                              icon: const Icon(Icons.verified_outlined),
                              label: const Text('Approve & Verify'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text('Awaiting Payment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (paymentPending.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No claims awaiting payment.'),
                ),
              )
            else
              ...paymentPending.map((FieldClaimRequestRecord request) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(request.fieldName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Claimant: ${request.claimantName ?? request.claimantUserId}'),
                        Text('Payment status: ${request.paymentStatus ?? 'payment_requested'}'),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            ElevatedButton(
                              onPressed: () => _approveClaim(request.id),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('Confirm Payment & Approve'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text('Claim History', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No reviewed claims yet.'),
                ),
              )
            else
              ...history.map((FieldClaimRequestRecord request) {
                final bool approved =
                    request.verificationStatus.toLowerCase() == 'approved';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      (request.fieldName ?? '').trim().isEmpty
                          ? 'Field ${request.fieldId}'
                          : request.fieldName!,
                    ),
                    subtitle: Text(
                      '${request.staffName} • ${request.officialEmail}\nReviewed: ${request.reviewedAt ?? request.createdAt}',
                    ),
                    isThreeLine: true,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: approved
                            ? Colors.green.withAlpha(28)
                            : Colors.red.withAlpha(28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        approved ? 'Approved' : 'Rejected',
                        style: TextStyle(
                          color: approved ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildMembershipsTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([
        _membershipRequestsFuture,
        _reviewedMembershipFuture,
      ]),
      builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load memberships: ${snapshot.error}'),
            ),
          );
        }

        final List<dynamic> packed = snapshot.data ?? <dynamic>[];
        final List<MembershipRequestRecord> active = packed.isNotEmpty
            ? (packed[0] as List<MembershipRequestRecord>)
            : <MembershipRequestRecord>[];
        final List<MembershipRequestRecord> history = packed.length > 1
            ? (packed[1] as List<MembershipRequestRecord>)
            : <MembershipRequestRecord>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Pending Membership Requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (active.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No pending membership requests.'),
                ),
              )
            else
              ...active.map((MembershipRequestRecord req) {
                final bool isPaymentRequested = req.status == 'payment_requested';
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
                                req.fullName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            _MembershipStatusBadge(status: req.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Email: ${req.contactEmail}'),
                        Text('Fee: ¥${req.annualFeeYen}/year'),
                        if ((req.notes ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('User note: ${req.notes!}'),
                          ),
                        if ((req.adminNote ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Admin note: ${req.adminNote!}'),
                          ),
                        if (req.paymentRequestSentAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Payment requested: ${req.paymentRequestSentAt!.toLocal()}',
                            ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (!isPaymentRequested)
                              FilledButton.icon(
                                onPressed: _isBusy
                                    ? null
                                    : () => _sendMembershipPaymentRequest(req),
                                icon: const Icon(Icons.send_outlined, size: 16),
                                label: const Text('Send Payment Request'),
                              ),
                            if (isPaymentRequested)
                              FilledButton.icon(
                                onPressed: _isBusy
                                    ? null
                                    : () => _activateMembership(req),
                                icon: const Icon(Icons.check_circle_outline, size: 16),
                                label: const Text('Activate (payment received)'),
                              ),
                            FilledButton.tonalIcon(
                              onPressed: _isBusy
                                  ? null
                                  : () => _rejectMembership(req),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text(
              'Membership History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No reviewed membership requests.'),
                ),
              )
            else
              ...history.map((MembershipRequestRecord req) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(req.fullName),
                    subtitle: Text(
                      '${req.contactEmail}\n¥${req.annualFeeYen}/year'
                      '${req.expiresAt != null ? '\nExpires: ${req.expiresAt!.toLocal()}' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: _MembershipStatusBadge(status: req.status),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildSafetyTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([
        _safetyReportsFuture,
        _moderationQueueFuture,
        _moderationAuditFuture,
      ]),
      builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load safety data: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<dynamic> packed = snapshot.data ?? <dynamic>[];
        final List<SafetyReportRecord> reports = packed.isNotEmpty
            ? (packed[0] as List<SafetyReportRecord>)
            : <SafetyReportRecord>[];
        final List<ModerationQueueRecord> queue = packed.length > 1
            ? (packed[1] as List<ModerationQueueRecord>)
            : <ModerationQueueRecord>[];
        final List<ModerationAuditLogRecord> audit = packed.length > 2
            ? (packed[2] as List<ModerationAuditLogRecord>)
            : <ModerationAuditLogRecord>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Open Safety Reports',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (reports.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No reports submitted yet.'),
                ),
              )
            else
              ...reports.map((SafetyReportRecord report) {
                final bool isOpen = report.status == 'open';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${report.targetType.toUpperCase()} • ${report.reasonCategory}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Report ID: ${report.id}'),
                        Text('Reporter: ${report.reporterUserId}'),
                        if ((report.targetId ?? '').isNotEmpty)
                          Text('Target: ${report.targetId}'),
                        Text('Status: ${report.status}'),
                        if ((report.details ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(report.details!),
                          ),
                        const SizedBox(height: 10),
                        if (isOpen)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              FilledButton.tonal(
                                onPressed: _isBusy
                                    ? null
                                    : () => _reviewReport(report, 'triaged'),
                                child: const Text('Triage'),
                              ),
                              FilledButton(
                                onPressed: _isBusy
                                    ? null
                                    : () => _reviewReport(report, 'actioned'),
                                child: const Text('Actioned'),
                              ),
                              OutlinedButton(
                                onPressed: _isBusy
                                    ? null
                                    : () => _reviewReport(report, 'dismissed'),
                                child: const Text('Dismiss'),
                              ),
                            ],
                          )
                        else
                          const Text('Already reviewed'),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text(
              'Moderation Queue',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (queue.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Queue is empty.'),
                ),
              )
            else
              ...queue.map((ModerationQueueRecord item) {
                final bool assignedToMe =
                    item.assignedTo == Supabase.instance.client.auth.currentUser?.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${item.targetType} • ${item.priority}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: ${item.status}\nTarget: ${item.targetId ?? '-'}\nReport: ${item.reportId ?? '-'}\nAssigned: ${item.assignedTo ?? '-'}',
                        ),
                        _buildTargetPreview(item),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            OutlinedButton(
                              onPressed: (_isBusy || assignedToMe)
                                  ? null
                                  : () => _assignQueueItem(item),
                              child: Text(assignedToMe ? 'Assigned to me' : 'Assign to me'),
                            ),
                            FilledButton.tonal(
                              onPressed: _isBusy
                                  ? null
                                  : () => _changeQueueStatus(item, 'queued'),
                              child: const Text('Queued'),
                            ),
                            FilledButton.tonal(
                              onPressed: _isBusy
                                  ? null
                                  : () => _changeQueueStatus(item, 'in_review'),
                              child: const Text('In review'),
                            ),
                            FilledButton(
                              onPressed: _isBusy
                                  ? null
                                  : () => _changeQueueStatus(item, 'resolved'),
                              child: const Text('Resolve'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text(
              'Moderation Audit Log',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (audit.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No moderation actions recorded.'),
                ),
              )
            else
              ...audit.map((ModerationAuditLogRecord row) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(row.action),
                    subtitle: Text(
                      'Target: ${row.targetType} ${row.targetId ?? ''}\nModerator: ${row.moderatorUserId ?? '-'}',
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdminFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Area')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Area')),
            body: _buildAccessDenied(error: snapshot.error),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Area'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Moderation'),
                Tab(text: 'Safety'),
                Tab(text: 'Users'),
                Tab(text: 'Official'),
                Tab(text: 'Claims'),
                Tab(text: 'Memberships'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildModerationTab(),
              _buildSafetyTab(),
              _buildUsersTab(),
              _buildOfficialTab(),
              _buildClaimsTab(),
              _buildMembershipsTab(),
            ],
          ),
        );
      },
    );
  }
}

class _MembershipStatusBadge extends StatelessWidget {
  const _MembershipStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'active' => (Colors.green.withAlpha(38), Colors.green.shade800),
      'payment_requested' => (Colors.blue.withAlpha(28), Colors.blue.shade700),
      'approved' => (Colors.teal.withAlpha(28), Colors.teal.shade700),
      'rejected' || 'expired' => (Colors.red.withAlpha(28), Colors.red.shade700),
      _ => (
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AdminDashboardData {
  const _AdminDashboardData({
    required this.posts,
    required this.comments,
    required this.events,
    required this.fields,
    required this.bans,
    required this.shops,
  });

  final List<CommunityPostModel> posts;
  final List<CommunityCommentModel> comments;
  final List<EventModel> events;
  final List<FieldModel> fields;
  final List<AdminBanRecord> bans;
  final List<ShopModel> shops;
}
