import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  DateTime? _dateOfBirth;

  bool _isLoading = false;

  Future<void> _pickDateOfBirth() async {
    final DateTime now = DateTime.now();
    final DateTime initial =
        _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dateOfBirth = picked;
    });
  }

  String _formatDate(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  Future<void> _signup() async {
    final l10n = AppLocalizations.of(context);
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (name.isEmpty) {
      _showMessage('Name is required');
      return;
    }
    if (email.isEmpty) {
      _showMessage(l10n.t('email'));
      return;
    }
    if (password.isEmpty) {
      _showMessage(l10n.t('password'));
      return;
    }
    if (_dateOfBirth == null) {
      _showMessage('Date of birth is required');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'call_sign': name,
          'full_name': name,
          'date_of_birth': _formatDate(_dateOfBirth!),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('signupSuccess'))));
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showMessage(l10n.t('signupFailed', args: {'error': '$e'}));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('createAccount'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'Name shown on your profile',
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _isLoading ? null : _pickDateOfBirth,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of birth',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          _dateOfBirth == null
                              ? 'Select date of birth'
                              : _formatDate(_dateOfBirth!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l10n.t('email')),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.t('password'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _signup,
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.t('createAccount')),
                      ),
                    ),
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
