import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
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
                      'Password reset email sent. Check your inbox.',
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
              title: const Text('Forgot password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your email address and we will send a password reset link.',
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: sending ? null : sendResetEmail,
                  child: sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send reset link'),
                ),
              ],
            );
          },
        );
      },
    );

    resetEmailController.dispose();
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
                    l10n.appTitle,
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
                      child: const Text('Forgot password?'),
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
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _loading ? null : _goToSignup,
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
