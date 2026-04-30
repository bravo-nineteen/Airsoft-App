import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'membership_repository.dart';

class MembershipRequestScreen extends StatefulWidget {
  const MembershipRequestScreen({super.key});

  @override
  State<MembershipRequestScreen> createState() => _MembershipRequestScreenState();
}

class _MembershipRequestScreenState extends State<MembershipRequestScreen> {
  final MembershipRepository _repository = MembershipRepository();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  MembershipRequestModel? _latestRequest;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final MembershipRequestModel? latest = await _repository.getLatestRequest();
      if (!mounted) {
        return;
      }
      setState(() {
        _latestRequest = latest;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _latestRequest = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final String fullName = _nameController.text.trim();
    final String email = _emailController.text.trim();

    if (fullName.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).membershipNameEmailRequired)),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await _repository.submitAnnualMembershipRequest(
        fullName: fullName,
        contactEmail: email,
        notes: _notesController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).membershipRequestSent,
          ),
        ),
      );

      _nameController.clear();
      _emailController.clear();
      _notesController.clear();
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('membershipSubmitFailed', args: {'error': error.toString()}))));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).annualMembership)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Builder(
                          builder: (BuildContext ctx) => Text(
                            AppLocalizations.of(ctx).annualPlan,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (BuildContext ctx) => Text(
                            AppLocalizations.of(ctx).membershipProcess,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _StatusChip(status: _latestRequest?.status ?? 'none'),
                        if ((_latestRequest?.adminNote ?? '').isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Builder(builder: (BuildContext ctx) => Text(AppLocalizations.of(ctx).t('membershipAdminNote', args: {'note': _latestRequest!.adminNote!}))),
                        ],
                        if (_latestRequest?.expiresAt != null) ...<Widget>[
                          const SizedBox(height: 6),
                          Builder(builder: (BuildContext ctx) => Text(AppLocalizations.of(ctx).t('membershipExpires', args: {'date': _latestRequest!.expiresAt!.toLocal().toString()}))),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Builder(builder: (BuildContext ctx) {
                  final AppLocalizations l10n = AppLocalizations.of(ctx);
                  return Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.membershipFullName,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: l10n.membershipContactEmail,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: l10n.membershipNotesHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: const Icon(Icons.send_outlined),
                        label: Text(_submitting ? l10n.membershipSubmitting : l10n.membershipRequestBtn),
                      ),
                    ],
                  );
                }),
              ],
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final String normalized = status.toLowerCase();
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final (Color bg, Color fg) = switch (normalized) {
      'active' => (Colors.green.withValues(alpha: 0.2), Colors.green.shade900),
      'approved' || 'payment_requested' => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
      'rejected' => (Colors.red.withValues(alpha: 0.2), Colors.red.shade900),
      _ => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(context, normalized),
        style: TextStyle(fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  String _statusLabel(BuildContext context, String normalized) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return switch (normalized) {
      'none' => l10n.membershipStatusNone,
      'pending' => l10n.membershipStatusPending,
      'approved' => l10n.membershipStatusApproved,
      'rejected' => l10n.membershipStatusRejected,
      'payment_requested' => l10n.membershipStatusPaymentRequested,
      'active' => l10n.membershipStatusActive,
      'expired' => l10n.membershipStatusExpired,
      _ => normalized,
    };
  }
}
