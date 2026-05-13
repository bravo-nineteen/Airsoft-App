import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _maxFailedAttempts = 4;
  static const Duration _lockDuration = Duration(minutes: 10);
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  OAuthProvider? _oauthLoadingProvider;
  String? _error;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  String get _attemptsKey => 'login-failed-attempts';
  String get _lockedUntilKey => 'login-locked-until';

  Future<DateTime?> _getLockedUntil() async {
    final SharedPreferences prefs = await _prefs;
    final int? millis = prefs.getInt(_lockedUntilKey);
    if (millis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<bool> _isLockedOut() async {
    final DateTime? lockedUntil = await _getLockedUntil();
    if (lockedUntil == null) {
      return false;
    }
    if (DateTime.now().isAfter(lockedUntil)) {
      final SharedPreferences prefs = await _prefs;
      await prefs.remove(_lockedUntilKey);
      await prefs.remove(_attemptsKey);
      return false;
    }
    return true;
  }

  Future<void> _registerFailedAttempt() async {
    final SharedPreferences prefs = await _prefs;
    final int attempts = prefs.getInt(_attemptsKey) ?? 0;
    final int nextAttempts = attempts + 1;
    await prefs.setInt(_attemptsKey, nextAttempts);
    if (nextAttempts >= _maxFailedAttempts) {
      await prefs.setInt(
        _lockedUntilKey,
        DateTime.now().add(_lockDuration).millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _clearFailedAttempts() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove(_attemptsKey);
    await prefs.remove(_lockedUntilKey);
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final DateTime? lockedUntil = await _getLockedUntil();
    if (await _isLockedOut()) {
      final Duration remaining = lockedUntil!.difference(DateTime.now());
      setState(() {
        _error =
            'Too many failed attempts. Try again in ${remaining.inMinutes + 1} minutes.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _clearFailedAttempts();
    } on AuthException catch (e) {
      await _registerFailedAttempt();
      final bool locked = await _isLockedOut();
      setState(() {
        _error = locked
            ? 'Too many failed attempts. This device is locked for 10 minutes.'
            : e.message;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _openForgotPasswordDialog() async {
    final l10n = AppLocalizations.of(context);
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool sending = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendResetEmail() async {
              final email = resetEmailController.text.trim();

              if (email.isEmpty) {
                setDialogState(() {
                  dialogError = l10n.t('email');
                });
                return;
              }

              setDialogState(() {
                sending = true;
                dialogError = null;
              });

              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(email);

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();

                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.t('passwordResetSent'),
                    ),
                  ),
                );
              } on AuthException catch (e) {
                setDialogState(() {
                  dialogError = e.message;
                });
              } catch (e) {
                setDialogState(() {
                  dialogError = e.toString();
                });
              } finally {
                if (mounted) {
                  setDialogState(() {
                    sending = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: Text(l10n.t('forgotPassword')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.t('forgotPasswordPrompt'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.t('email'),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.t('cancel')),
                ),
                FilledButton(
                  onPressed: sending ? null : sendResetEmail,
                  child: sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.t('sendResetLink')),
                ),
              ],
            );
          },
        );
      },
    );

    resetEmailController.dispose();
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    if (_loading || _oauthLoadingProvider != null) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _oauthLoadingProvider = provider;
      _error = null;
    });

    try {
      final bool launched = await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'fieldops://login-callback',
      );

      if (!launched && mounted) {
        setState(() {
          _error = 'Unable to open sign-in provider.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _oauthLoadingProvider = null;
        });
      }
    }
  }

  void _goToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SignupScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 48,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'FieldOps',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.t('email'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.t('password'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _openForgotPasswordDialog,
                      child: Text(l10n.t('forgotPasswordQuestion')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.t('login')),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          l10n.t('continueWith'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: (_loading || _oauthLoadingProvider != null)
                        ? null
                        : () => _signInWithProvider(OAuthProvider.google),
                    icon: _oauthLoadingProvider == OAuthProvider.google
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata_rounded, size: 28),
                    label: Text(l10n.t('signInWithGoogle')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: (_loading || _oauthLoadingProvider != null)
                        ? null
                        : () => _signInWithProvider(OAuthProvider.facebook),
                    icon: _oauthLoadingProvider == OAuthProvider.facebook
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.facebook_outlined),
                    label: Text(l10n.t('signInWithFacebook')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: (_loading || _oauthLoadingProvider != null)
                        ? null
                        : _goToSignup,
                    child: Text(l10n.t('signUp')),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
