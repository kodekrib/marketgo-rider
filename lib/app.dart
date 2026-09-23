import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';

/// MarketGO Rider — central theme + app root.
/// Visual language inspired by Uber Eats / DoorDash courier apps:
/// a bold brand accent with clean, card-based surfaces.
class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  static Color brandGreen = const Color(0xFF16A34A); // primary green
  static Color brandGreenDark = const Color(0xFF15803D);
  static Color brandGreenLight = const Color(0xFFDEF7E5);
  static const Color ink = Color(0xFF111418); // near-black for text
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF7F8FA);
  static String appName = 'MarketGO Rider';
  static String fontFamily = '';
  static bool maintenanceMode = false;
  static String currencySymbol = '₦';

  /// Apply branding loaded from the admin-managed public settings.
  static void applyBranding(AppSettings s) {
    if (s.brandColor != const Color(0xFF16A34A)) brandGreen = s.brandColor;
    if (s.brandDarkColor != const Color(0xFF15803D)) brandGreenDark = s.brandDarkColor;
    if (s.brandLightColor != const Color(0xFFDEF7E5)) brandGreenLight = s.brandLightColor;
    appName = s.appName;
    if (s.fontFamily.isNotEmpty) fontFamily = s.fontFamily;
    if (s.currencySymbol.isNotEmpty) currencySymbol = s.currencySymbol;
    maintenanceMode = s.maintenanceMode;
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light().colorScheme;
    final colorScheme = base.copyWith(
      primary: brandGreen,
      onPrimary: Colors.white,
      primaryContainer: brandGreenLight,
      onPrimaryContainer: brandGreenDark,
      secondary: brandGreenDark,
      onSecondary: Colors.white,
      surface: surface,
      error: const Color(0xFFB3261E),
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceMuted,
      fontFamily: fontFamily.isEmpty ? 'Helvetica Neue' : fontFamily,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF3A3F47)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF5B616A)),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E5EA), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E5EA), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: brandGreen, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );

    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => MaintenanceGate(child: child ?? const SizedBox.shrink()),
      home: const LoginScreen(),
    );
  }
}

/// Watches public settings and swaps the whole app to a maintenance screen
/// whenever the admin enables platform-wide maintenance mode.
class MaintenanceGate extends StatefulWidget {
  const MaintenanceGate({super.key, required this.child});

  final Widget child;

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate> {
  Timer? _timer;
  bool maintenance = RiderApp.maintenanceMode;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = await SettingsService.fetchSettings();
    if (!mounted) return;
    final on = s.maintenanceMode;
    if (on != maintenance) {
      setState(() => maintenance = on);
    }
  }

  @override
  Widget build(BuildContext context) {
    return maintenance ? const MaintenanceScreen() : widget.child;
  }
}

/// Full-screen notice shown while the platform is under maintenance.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: RiderApp.brandGreenLight,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(Icons.build_circle_rounded,
                      size: 46, color: RiderApp.brandGreenDark),
                ),
                const SizedBox(height: 24),
                Text(
                  '${RiderApp.appName} is under maintenance',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  "We're performing scheduled maintenance right now. "
                  'Please check back shortly — we will be back up soon.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen shown after a successful login: the rider home/dashboard.
class RiderHome extends StatelessWidget {
  const RiderHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
