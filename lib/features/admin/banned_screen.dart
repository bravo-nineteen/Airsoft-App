import 'package:flutter/material.dart';

import 'admin_repository.dart';

class BannedScreen extends StatelessWidget {
  const BannedScreen({
    super.key,
    required this.ban,
  });

  final AdminBanRecord ban;

  String _untilLabel() {
    if (ban.isPermanent) {
      return 'Permanent ban';
    }
    if (ban.bannedUntil == null) {
      return 'Temporary ban';
    }
    return 'Banned until ${ban.bannedUntil!.toLocal()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gpp_bad_outlined, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Account Restricted',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _untilLabel(),
                      textAlign: TextAlign.center,
                    ),
                    if ((ban.reason ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Reason: ${ban.reason}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
