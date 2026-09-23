import 'dart:async';

import 'package:flutter/material.dart';
import '../app.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Phone/OTP sign-in screen used by the "Phone" and "OTP" options on login.
///
/// Two steps: request a code against a Nigerian phone number, then enter the
/// 6-digit code. Codes are delivered by the marketgo-api (WhatsApp and/or
/// email). When developer preview is enabled the code is shown on the card.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.onVerified, this.title});

  final VoidCallback onVerified;
  final String? title;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _phoneController = TextEditingController();
  final _codeFocus = FocusNode();
  final _codeController = TextEditingController();
  final List<String> _digits = List.filled(6, '');

  Timer? _timer;
  int _secondsLeft = 30;
  bool _sent = false;
  bool _loading = false;
  bool _verifying = false;
  String? _error;
  String? _devCode;
  String _phone = '';

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) {
        t.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      }
    });
  }

  bool get _canResend => _sent && _secondsLeft == 0;

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    if (!_validPhone(phone)) {
      setState(() => _error = 'Enter a valid phone number, e.g. 08012345678.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final normalized = _normalizePhone(phone);
    try {
      final result = await AuthSession.instance.sendOtp(normalized);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
        _phone = normalized;
        _devCode = result.devCode;
      });
      _startTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _codeFocus.requestFocus();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not request a code. Check your connection and try again.';
      });
    }
  }

  void _resend() {
    _codeController.clear();
    setState(() {
      _digits.fillRange(0, 6, '');
      _error = null;
    });
    _sendCode();
  }

  void _onCodeChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '').padRight(6, ' ');
    setState(() {
      _digits.fillRange(0, 6, '');
      for (var i = 0; i < 6; i++) {
        _digits[i] = digits[i] == ' ' ? '' : digits[i];
      }
    });
    if (value.replaceAll(RegExp(r'[^0-9]'), '').length == 6) {
      _verify();
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length != 6) {
      setState(() => _error = 'Enter the full 6-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await AuthSession.instance.signInWithOtp(_phone, code);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _verifying = false);
    widget.onVerified();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: RiderApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: true,
        title: Text(widget.title ?? 'Verify your phone'),
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
              child: Icon(Icons.sms_outlined,
                  size: 36, color: RiderApp.brandGreenDark),
            ),
            const SizedBox(height: 20),
            Text(
              _sent ? 'Enter the code' : 'Phone number',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              _sent
                  ? 'We sent a 6-digit code to $_phone via WhatsApp and/or email.'
                  : 'We\'ll send you a one-time code to sign in quickly.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            if (!_sent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sendCode(),
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '080 1234 5678',
                  prefixText: '+234 ',
                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                ),
              ),
              if (_error != null) _ErrorBanner(message: _error!),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendCode,
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.6, color: Colors.white),
                        )
                      : const Text('Send code'),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RiderApp.brandGreenLight,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: RiderApp.brandGreenDark),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _devCode != null && _devCode!.isNotEmpty
                            ? 'Developer preview — your code is $_devCode.'
                            : 'Testing without delivery? Enable "Show code in response" in the admin settings.',
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
                style: const TextStyle(fontSize: 0.1, color: Colors.transparent),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              if (_error != null) _ErrorBanner(message: _error!),
              const SizedBox(height: 8),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
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
                child: _canResend
                    ? TextButton(
                        onPressed: _resend,
                        child: const Text('Resend code'),
                      )
                    : Text(
                        'Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _validPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11 && digits.startsWith('0')) return true;
    if (digits.length == 13 && digits.startsWith('234')) return true;
    return false;
  }

  /// Converts accepted local formats to the bare local number the backend
  /// normalises (234… → 0…).
  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 13 && digits.startsWith('234')) {
      return '0${digits.substring(3)}';
    }
    return digits;
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