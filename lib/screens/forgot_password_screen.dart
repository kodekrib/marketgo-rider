import 'package:flutter/material.dart';
import '../app.dart';

/// Password recovery screen — requests a reset link for a rider account.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter the email linked to your account.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: RiderApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Forgot password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: _sent
            ? _SuccessView(email: _emailController.text.trim())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: RiderApp.brandGreenLight,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 36,
                      color: RiderApp.brandGreenDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Reset your password',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the email on your MarketGO account and we\'ll send '
                    'you a link to choose a new password.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'you@marketgo.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFB3261E), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFF8F1D16),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.6, color: Colors.white),
                            )
                          : const Text('Send reset link'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: RiderApp.brandGreenLight,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mark_email_read_rounded,
              size: 44, color: RiderApp.brandGreenDark),
        ),
        const SizedBox(height: 20),
        Text('Check your inbox', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'We sent a password reset link to\n$email',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.tonal(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Back to sign in'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {},
          child: const Text('Resend email'),
        ),
      ],
    );
  }
}