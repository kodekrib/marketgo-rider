import 'package:flutter/material.dart';
import '../app.dart';
import '../models/faq.dart';
import '../services/faq_service.dart';

/// Full-screen Help & Support for the rider app: FAQs from the backend plus
/// contact options. Replaces the old placeholder InfoScreen.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final FaqService _faqs = FaqService();
  List<FaqEntry>? _entries;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await _faqs.byTarget('rider');
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries = riderDemoFaqs();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: RiderApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Help & support'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [RiderApp.brandGreenDark, RiderApp.brandGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.help_outline_rounded, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Support is available around the clock for riders.',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: Icons.phone_outlined,
                  label: 'Call us',
                  onTap: () => _toast('Support line coming soon.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContactCard(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  onTap: () => _toast('Email support coming soon.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContactCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  onTap: () => _toast('Live chat coming soon.'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Frequently asked questions',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (entries != null)
            ...entries.map(
              (e) => _FaqTile(question: e.question, answer: e.answer),
            ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: RiderApp.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: RiderApp.brandGreenDark),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: RiderApp.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(question,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(answer, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}