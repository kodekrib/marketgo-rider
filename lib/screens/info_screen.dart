import 'package:flutter/material.dart';
import '../app.dart';

/// Simple placeholder detail screen for rider account menu items.
class InfoScreen extends StatelessWidget {
  const InfoScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    this.bullets = const [],
  });

  final String title;
  final IconData icon;
  final String description;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: RiderApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: RiderApp.brandGreenLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 38, color: RiderApp.brandGreenDark),
            ),
            const SizedBox(height: 20),
            Text(description, style: theme.textTheme.bodyLarge),
            if (bullets.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: RiderApp.brandGreenDark),
                      const SizedBox(width: 10),
                      Expanded(child: Text(b, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}