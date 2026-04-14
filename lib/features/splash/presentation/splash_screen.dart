import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/config/app_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _progress += 0.18;
        if (_progress >= 1.0) {
          _progress = 1.0;
          timer.cancel();
          Navigator.of(context).pushReplacementNamed(AppRouter.shell);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.secondary, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  'AOJ',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: _progress, minHeight: 10),
              ),
              const Spacer(),
              Text(
                AppConfig.appVersion,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                AppConfig.appCredit,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
