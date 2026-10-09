import 'package:flutter/material.dart';
import '../app.dart';
import '../services/auth_service.dart';

/// Multi-factor authentication screen shown after a password login that was
/// answered with an MFA challenge.
///
/// Collects the 6-digit one-time code (delivered over the challenge channels,
/// typically email), verifies it against `/api/v1/auth/mfa/verify` and enters
/// the authenticated session. When developer preview is enabled the code is
/// echoed on the card.
class MfaScreen extends StatefulWidget {
  const MfaScreen({
    super.key,
    required this.auth,
    required this.email,
    required this.onVerified,
  });

  final AuthSession auth;
  final String email;
  final VoidCallback onVerified;

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final _codeFocus = FocusNode();
  final _codeController = TextEditingController();
  final List<String> _digits = List.filled(6, '');

  bool _verified = false;
  String? _inputError;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '').padRight(6, ' ');
    setState(() {
      _digits.fillRange(0, 6, '');
      for (var i = 0; i < 6; i++) {
        _digits[i] = digits[i] == ' ' ? '' : digits[i];
      }
      if (_inputError != null) _inputError = null;
    });
    if (value.replaceAll(RegExp(r'[^0-9]'), '').length == 6) {
      _verify();
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length != 6) {
      setState(() => _inputError = 'Enter the full 6-digit code.');
      return;
    }
    FocusScope.of(context).unfocus();
    final verified = await widget.auth.verifyMfaCode(code);
    if (!mounted) return;
    if (!verified) return;
    setState(() => _verified = true);
    // [onVerified] swaps in the home screen and drops this route.
    widget.onVerified();
  }

  /// Leaves the screen without verifying, dropping the pending challenge.
  void _back() {
    Navigator.of(context).pop();
    if (!_verified) widget.auth.cancelMfa();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devCode = widget.auth.pendingMfa?.devCode;
    return AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) {
        final error = widget.auth.error ?? _inputError;
        final loading = widget.auth.loading;
        return PopScope(
          onPopInvoked: (didPop) {
            if (didPop && !_verified) widget.auth.cancelMfa();
          },
          child: Scaffold(
            backgroundColor: RiderApp.surfaceMuted,
            appBar: AppBar(
              backgroundColor: RiderApp.surfaceMuted,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: true,
              title: const Text('Two-factor authentication'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: RiderApp.brandGreenLight,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.verified_user_outlined,
                        size: 36, color: RiderApp.brandGreenDark),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Enter the security code',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'For your security, enter the 6-digit code we sent to '
                    '${widget.email}.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  if (devCode != null && devCode.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RiderApp.brandGreenLight,
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 20, color: RiderApp.brandGreenDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Developer preview — your code is $devCode.',
                              style: TextStyle(
                                color: RiderApp.brandGreenDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  GestureDetector(
                    onTap: () => _codeFocus.requestFocus(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        final selected = _codeFocus.hasFocus;
                        return Container(
                          width: 46,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _digits[i].isNotEmpty
                                  ? RiderApp.brandGreen
                                  : const Color(0xFFE2E5EA),
                              width: selected &&
                                      _digits[i].isEmpty &&
                                      i == _codeController.text.length
                                  ? 2
                                  : 1.2,
                            ),
                          ),
                          child: Text(
                            _digits[i],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    focusNode: _codeFocus,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    maxLines: 1,
                    autofocus: true,
                    onChanged: _onCodeChanged,
                    style:
                        const TextStyle(fontSize: 0.1, color: Colors.transparent),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                  if (error != null) _ErrorBanner(message: error),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: loading ? null : _verify,
                      child: loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.6, color: Colors.white),
                            )
                          : const Text('Verify & sign in'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: loading ? null : _back,
                      child: const Text('Back to sign in'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                message,
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
    );
  }
}
