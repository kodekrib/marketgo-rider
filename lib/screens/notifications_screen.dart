import 'package:flutter/material.dart';
import '../app.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Notifications center — delivery offers, system notices and earnings alerts.
/// Loads real notifications from the backend; falls back to demo placeholders.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final RiderNotificationService _service = RiderNotificationService();
  List<RiderNotification>? _notifications;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthSession.instance.accessToken;
    if (token == null || token == 'demo.access') {
      setState(() => _notifications = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final notifs = await _service.list(token);
      if (!mounted) return;
      setState(() {
        _notifications = notifs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifications = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifs = _notifications;

    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: RiderApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Notifications'),
        actions: [
          if (notifs != null && notifs.isNotEmpty)
            TextButton(
              onPressed: () async {
                final token = AuthSession.instance.accessToken;
                if (token == null) return;
                await _service.markAllRead(token);
                _load();
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : notifs == null
              ? _buildDemoList(theme)
              : notifs.isEmpty
                  ? Center(
                      child: Text(
                        'No notifications yet.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : _buildRealList(notifs, theme),
    );
  }

  Widget _buildRealList(List<RiderNotification> notifs, ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: notifs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final n = notifs[index];
        final icon = _iconForType(n.type);
        final color = _colorForType(n.type);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: n.isRead ? Colors.white : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(n.body, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(n.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDemoList(ThemeData theme) {
    const items = <(String, String, String, IconData, Color)>[
      (
        'New delivery request',
        'Pick up from Vendor Hub to 12 Admiralty Way, Lekki. Fare ₦1,500.',
        'Just now',
        Icons.local_shipping_outlined,
        Color(0xFF16A34A),
      ),
      (
        'Payout scheduled',
        'Your Thursday payout of ₦3,200 is on its way to your bank.',
        'Yesterday',
        Icons.payments_outlined,
        Color(0xFF2563EB),
      ),
      (
        'Shift bonus unlocked',
        'Complete 20 trips this week to earn an extra ₦5,000.',
        'Sep 3',
        Icons.emoji_events_outlined,
        Color(0xFFF59E0B),
      ),
      (
        'Welcome to MarketGO Riders',
        'Upload your documents to start receiving delivery requests.',
        'Sep 1',
        Icons.waving_hand_rounded,
        Color(0xFF7C3AED),
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final (title, body, time, icon, color) = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(body, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Text(time,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'delivery':
        return Icons.local_shipping_outlined;
      case 'order':
        return Icons.receipt_long_rounded;
      case 'payment':
        return Icons.payments_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'delivery':
        return const Color(0xFF16A34A);
      case 'order':
        return const Color(0xFF2563EB);
      case 'payment':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
