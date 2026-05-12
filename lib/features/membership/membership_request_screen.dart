import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/services/annual_membership_service.dart';

class MembershipRequestScreen extends StatefulWidget {
  const MembershipRequestScreen({super.key});

  @override
  State<MembershipRequestScreen> createState() => _MembershipRequestScreenState();
}

class _MembershipRequestScreenState extends State<MembershipRequestScreen> {
  final AnnualMembershipService _membershipService =
      AnnualMembershipService.instance;

  bool _loading = true;
  bool _termsAccepted = false;
  bool _purchasing = false;
  List<ProductDetails> _products = const <ProductDetails>[];
  DateTime? _cachedExpiry;

  @override
  void initState() {
    super.initState();
    _load();
    _membershipService.isAdFreeNotifier.addListener(_handleMembershipChanged);
  }

  @override
  void dispose() {
    _membershipService.isAdFreeNotifier.removeListener(_handleMembershipChanged);
    super.dispose();
  }

  void _handleMembershipChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      await _membershipService.ensureInitialized();
      final List<ProductDetails> products = await _membershipService.loadProducts();
      final DateTime? expiry = await _membershipService.getCachedExpiry();
      if (!mounted) {
        return;
      }
      setState(() {
        _products = products;
        _cachedExpiry = expiry;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _products = const <ProductDetails>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _restore() async {
    if (_purchasing) {
      return;
    }

    setState(() {
      _purchasing = true;
    });

    try {
      await _membershipService.restorePurchases();
      await _membershipService.refreshEntitlement();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase history restored.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore purchases: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _purchasing = false;
        });
      }
    }
  }

  Future<void> _purchase() async {
    if (_purchasing) {
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accept the terms before purchasing.')),
      );
      return;
    }
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Play subscription not configured yet. Set IAP_ANNUAL_MEMBERSHIP_SUBSCRIPTION_ID.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _purchasing = true;
    });

    try {
      final purchase = await _membershipService.purchaseAnnualMembership();
      if (!mounted) {
        return;
      }

      if (purchase == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase was canceled or timed out.')),
        );
        return;
      }

      await _membershipService.refreshEntitlement();
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annual membership activated. Ads are now disabled.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _purchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isAdFree = _membershipService.isAdFreeNotifier.value;
    final ProductDetails? product = _products.isNotEmpty ? _products.first : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.annualMembership)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Ad-free annual membership',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Remove in-app ads and unlock official field ownership claims through an annual Google Play subscription.',
                        ),
                        const SizedBox(height: 12),
                        _StatusBadge(
                          active: isAdFree,
                          expiry: _cachedExpiry,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Terms: if you claim a field that you are not actually affiliated with, your access and ownership may be revoked after review.',
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _termsAccepted,
                          onChanged: (bool? value) {
                            setState(() {
                              _termsAccepted = value ?? false;
                            });
                          },
                          title: const Text('I agree to the terms above.'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (product != null) ...<Widget>[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: const Text('Google Play annual subscription'),
                      subtitle: Text(product.price),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _purchasing || isAdFree ? null : _purchase,
                  icon: _purchasing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shopping_cart_checkout_outlined),
                  label: Text(
                    isAdFree
                        ? 'Membership active'
                      : (product == null
                        ? 'Configure Google Play subscription'
                        : 'Subscribe with Google Play'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _purchasing ? null : _restore,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('Restore purchases'),
                ),
              ],
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active, this.expiry});

  final bool active;
  final DateTime? expiry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color background = active
        ? Colors.green.withValues(alpha: 0.18)
        : colors.surfaceContainerHighest;
    final Color foreground = active ? Colors.green.shade900 : colors.onSurfaceVariant;
    final String expiryLabel = expiry == null ? '' : ' until ${expiry!.toLocal()}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        active ? 'Active$expiryLabel' : 'Not active yet',
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
