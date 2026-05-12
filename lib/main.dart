import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/content/app_content_preloader.dart';
import 'core/config/app_config.dart';
import 'shared/services/annual_membership_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'features/auth/reset_password_screen.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notification = message.notification;
  if (notification == null) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(
    const InitializationSettings(android: androidSettings),
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'fieldops_push_foreground',
          'FieldOps Push Notifications',
          description: 'Notifications shown while app is in foreground',
          importance: Importance.high,
        ),
      );
  await plugin.show(
    message.messageId.hashCode,
    notification.title,
    notification.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'fieldops_push_foreground',
        'FieldOps Push Notifications',
        channelDescription: 'Notifications shown while app is in foreground',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MobileAds.instance.initialize();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  bool _startupDone = false;
  String? _startupError;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await AppConfig.initializeSupabase();

      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((data) {
            if (data.session != null) {
              unawaited(AppContentPreloader.instance.ensureStarted());
            }
            if (data.event == AuthChangeEvent.passwordRecovery) {
              final navigator = _navigatorKey.currentState;
              if (navigator == null) return;

              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => const ResetPasswordScreen(),
                ),
              );
            }
          });

      if (!mounted) return;
      setState(() {
        _startupDone = true;
      });

      unawaited(_runDeferredStartupWork());
    } catch (error, stackTrace) {
      debugPrint('Startup failed: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      setState(() {
        _startupError = error.toString();
      });
    }
  }

  Future<void> _runDeferredStartupWork() async {
    try {
      await AnnualMembershipService.instance.ensureInitialized();
    } catch (error, stackTrace) {
      debugPrint('Deferred membership init failed: $error');
      debugPrint('$stackTrace');
    }

    try {
      await PushNotificationService.init().timeout(const Duration(seconds: 8));
    } catch (error, stackTrace) {
      debugPrint('Deferred push init failed: $error');
      debugPrint('$stackTrace');
    }

    if (Supabase.instance.client.auth.currentSession != null) {
      try {
        await AppContentPreloader.instance.ensureStarted();
      } catch (error, stackTrace) {
        debugPrint('Deferred content preload failed: $error');
        debugPrint('$stackTrace');
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return StartupErrorApp(message: _startupError!);
    }

    if (!_startupDone) {
      return const SplashScreen();
    }

    return AirsoftApp(navigatorKey: _navigatorKey);
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _pulseAnimation;
  String _versionLabel = '';

  static const Color _bg = Color(0xFF101513);
  static const Color _surface = Color(0xFF17201C);
  static const Color _olive = Color(0xFF657153);
  static const Color _sand = Color(0xFFD2C29A);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _logoScaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 0.985, end: 1.015).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _pulseController.repeat(reverse: true);
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionLabel = 'v${info.version} (${info.buildNumber})';
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_surface, _bg],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GridPainter(
                    lineColor: _olive.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _logoScaleAnimation,
                          _pulseAnimation,
                        ]),
                        builder: (context, child) {
                          final scale =
                              _logoScaleAnimation.value * _pulseAnimation.value;

                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          width: 132,
                          height: 132,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _surface.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _sand.withValues(alpha: 0.45),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _olive.withValues(alpha: 0.28),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.shield_outlined,
                                size: 64,
                                color: _sand,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'FieldOps',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'フィールドオプス',
                        style: TextStyle(
                          fontSize: 17,
                          color: _sand.withValues(alpha: 0.95),
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 210,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _olive.withValues(alpha: 0.25),
                              _sand.withValues(alpha: 0.75),
                              _olive.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(_sand),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'in partnership with Airsoft Online Japan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.78),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_versionLabel.isNotEmpty)
                        Text(
                          _versionLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: _olive.withValues(alpha: 0.95),
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    const double gap = 36;

    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'App failed to start',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fix configuration and restart the app.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Details:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
