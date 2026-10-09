import 'package:flutter/material.dart';
import '../app.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../widgets/route_animation.dart';
import 'forgot_password_screen.dart';
import 'mfa_screen.dart';
import 'otp_screen.dart';

/// Intro / login screen for the MarketGO rider app.
///
/// "Premium split" layout: a dark gradient hero band fills the top with the
/// brand mark, a short value proposition and a subtle background pattern,
/// while a light, rounded card panel overlaps the lower edge and holds the
/// sign-in form. Rendered with a professional, courier-app feel.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _keepSignedIn = true;
  bool _loading = false;
  String? _error;
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    SettingsService.fetchSettings().then((s) {
      if (mounted) setState(() => _settings = s);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password to continue.');
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

    bool signedIn;
    try {
      signedIn = await AuthSession.instance.signIn(email, password);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (!signedIn) {
      // Password login needs a second factor — hand over to the MFA screen.
      if (AuthSession.instance.pendingMfa != null) _openMfa(email);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const RiderHome()),
    );
  }

  /// Opens the phone/OTP sign-in flow. The OTP screen verifies the code with
  /// the backend and enters the authenticated session before navigating on.
  void _openOtp() {
    FocusScope.of(context).unfocus();
    final nav = Navigator.of(context);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => OtpScreen(
          onVerified: () {
            nav.pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const RiderHome()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  /// Opens the MFA code screen after a password login that was answered with
  /// a challenge. Verifying completes the session and navigates on.
  void _openMfa(String email) {
    FocusScope.of(context).unfocus();
    final nav = Navigator.of(context);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => MfaScreen(
          auth: AuthSession.instance,
          email: email,
          onVerified: () {
            nav.pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const RiderHome()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      body: Stack(
        children: [
          // ---- Hero band (top 46% of screen) ----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.46,
            child: const _HeroBand(vehicleIcon: Icons.moped_rounded),
          ),

          // ---- Foreground scrollable content ----
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  // Back button floating over the hero.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          tooltip: 'Back',
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),

                  SizedBox(height: size.height * 0.10),
                  _HeroContent(settings: _settings),

                  // Overlapping login panel.
                  const SizedBox(height: 28),
                  Container(
                    width: size.width,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: const BoxDecoration(
                      color: RiderApp.surfaceMuted,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LoginCard(
                          emailController: _emailController,
                          passwordController: _passwordController,
                          emailFocus: _emailFocus,
                          passwordFocus: _passwordFocus,
                          obscure: _obscure,
                          onToggleObscure: () =>
                              setState(() => _obscure = !_obscure),
                          keepSignedIn: _keepSignedIn,
                          onToggleKeep: (v) =>
                              setState(() => _keepSignedIn = v),
                          error: _error,
                          loading: _loading,
                          onSignIn: _signIn,
                          onOpenOtp: _openOtp,
                          requestFocusPassword: () =>
                              _passwordFocus.requestFocus(),
                          appName: _settings?.appName ?? 'MarketGO',
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'By continuing you agree to the Rider Terms of '
                          'Service and acknowledge our Privacy Policy.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontSize: 12, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark gradient hero with a live animated route motif and the brand mark.
class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.vehicleIcon});

  final IconData vehicleIcon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E3A24),
            Color(0xFF16A34A),
          ],
        ),
      ),
      child: AnimatedRouteBackdrop(vehicleIcon: vehicleIcon),
    );
  }
}

/// Brand mark + welcome text.
class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.settings});

  final AppSettings? settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BrandTile(settings: settings),
        const SizedBox(height: 20),
        const Text(
          'Welcome back',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Sign in to pick up deliveries, track earnings and take control of your shift.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.settings});

  final AppSettings? settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: settings?.logoUrl.isNotEmpty == true
          ? ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.network(
                settings!.logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.moped_rounded,
                  size: 52,
                  color: RiderApp.brandGreen,
                ),
              ),
            )
          : Icon(Icons.moped_rounded, size: 52, color: RiderApp.brandGreen),
    );
  }
}

/// The white sign-in form panel.
class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscure,
    required this.onToggleObscure,
    required this.keepSignedIn,
    required this.onToggleKeep,
    required this.error,
    required this.loading,
    required this.onSignIn,
    required this.onOpenOtp,
    required this.requestFocusPassword,
    required this.appName,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final bool keepSignedIn;
  final ValueChanged<bool> onToggleKeep;
  final String? error;
  final bool loading;
  final VoidCallback onSignIn;
  final VoidCallback onOpenOtp;
  final VoidCallback requestFocusPassword;
  final String appName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Sign in', style: theme.textTheme.headlineMedium),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ForgotPasswordScreen(),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: RiderApp.brandGreenDark,
              ),
              child: const Text('Forgot password?'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Use your $appName rider account to continue.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),

        TextField(
          controller: emailController,
          focusNode: emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => requestFocusPassword(),
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'you@marketgo.com',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passwordController,
          focusNode: passwordFocus,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => onSignIn(),
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              tooltip: obscure ? 'Show password' : 'Hide password',
            ),
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    error!,
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

        const SizedBox(height: 8),
        Row(
          children: [
            Switch(
              value: keepSignedIn,
              onChanged: onToggleKeep,
              activeTrackColor: RiderApp.brandGreen,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Keep me signed in',
                  style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
        const SizedBox(height: 6),

        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: loading ? null : onSignIn,
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: Colors.white,
                    ),
                  )
                : const Text('Sign in'),
          ),
        ),

        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or continue with',
                  style: theme.textTheme.bodyMedium),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _OutlineAction(
                icon: Icons.phone_iphone_rounded,
                label: 'Phone',
                onTap: onOpenOtp,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OutlineAction(
                icon: Icons.mark_email_read_outlined,
                label: 'OTP',
                onTap: onOpenOtp,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: Color(0xFFD5DAE1)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: RiderApp.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: RiderApp.brandGreenDark),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
