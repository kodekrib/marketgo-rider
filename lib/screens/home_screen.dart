import 'dart:async';

import 'package:flutter/material.dart';
import '../app.dart';
import '../services/auth_service.dart';
import '../services/delivery_service.dart';
import '../services/mover_service.dart';
import '../services/websocket_service.dart';
import 'bank_account_screen.dart';
import 'delivery_addresses_screen.dart';
import 'favourites_screen.dart';
import 'help_screen.dart';
import 'info_screen.dart';
import 'login_screen.dart';
import 'movers_tab.dart';
import 'navigation_screen.dart';
import 'notifications_screen.dart';
import 'payment_methods_screen.dart';
import 'withdrawal_screen.dart';

/// MarketGO Rider landing page shown after login.
/// Uber Eats / DoorDash courier dashboard style: big online/offline toggle,
/// earnings summary, incoming delivery offer, delivery pipeline, and bottom nav.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  bool _online = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _tabKey(_tabIndex),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 8,
            child: _NotificationsButton(),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }

  Widget _tabKey(int i) {
    switch (i) {
      case 0:
        return _HomeTab(
          online: _online,
          onToggleOnline: (v) => setState(() => _online = v),
        );
      case 1:
        return const _DeliveriesTab();
      case 2:
        return MoversTab(service: MoverService(api: AuthSession.instance.api));
      case 3:
        return const _EarningsTab();
      default:
        return const _AccountTab();
    }
  }
}

// ---------------------------------------------------------------------------
// Bottom navigation
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
final items = [
    (Icons.home_rounded, 'Home'),
    (Icons.delivery_dining_rounded, 'Deliveries'),
    (Icons.fire_truck_rounded, 'Movers'),
    (Icons.payments_rounded, 'Earnings'),
    (Icons.person_rounded, 'Account'),
  ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(items.length, (index) {
          final (icon, label) = items[index];
          final selected = index == currentIndex;
          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: selected
                        ? RiderApp.brandGreenDark
                        : const Color(0xFF9AA1AA),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? RiderApp.brandGreenDark
                          : const Color(0xFF9AA1AA),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home tab
// ---------------------------------------------------------------------------

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.online, required this.onToggleOnline});

  final bool online;
  final ValueChanged<bool> onToggleOnline;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final DeliveryService service =
      DeliveryService(api: AuthSession.instance.api);

  RiderDelivery? _available;
  RiderDelivery? _current;
  DeliveryEarnings? _earnings;
  RiderWebSocket? _ws;
  StreamSubscription<RiderWsEvent>? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _connectTripUpdates();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws?.dispose();
    super.dispose();
  }

  /// Live trip feed: a new delivery request pops up immediately and trip
  /// acceptance/status changes keep the offer card in sync with the customer.
  void _connectTripUpdates() {
    final token = AuthSession.instance.accessToken;
    if (token == null || token == 'demo.access') return;
    _ws = RiderWebSocket(api: AuthSession.instance.api);
    _ws!.connect(token);
    _wsSub = _ws!.events
        .where((e) =>
            e.type == 'delivery.available' ||
            e.type == 'delivery.status_changed')
        .listen((_) => _load());
  }

  Future<void> _load() async {
    final token = AuthSession.instance.accessToken;
    if (token == null || token == 'demo.access') return;
    try {
      final available = await service.available(token);
      final current = await service.current(token);
      final earnings = await service.earnings(token);
      if (!mounted) return;
      setState(() {
        _available = available.isEmpty ? null : available.first;
        _current = current;
        _earnings = earnings;
      });
    } catch (_) {
      // Keep whatever we already have; the tab shows nothing until a live
      // request arrives.
    }
  }

  Future<void> _accept(RiderDelivery d) async {
    final token = AuthSession.instance.accessToken;
    if (token == null || token == 'demo.access') {
      _openNavigation(d);
      return;
    }
    try {
      await service.accept(token, d.id);
      if (!mounted) return;
      setState(() {
        _current = d;
        _available = null;
      });
      // Pull the server's accepted trip so the status card reflects the
      // driver-acceptance state shared with the customer app.
      await _load();
      if (!mounted) return;
      _openNavigation(d);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not accept: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openNavigation(RiderDelivery? d) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NavigationScreen(delivery: d)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        AuthSession.instance.user?.firstName ?? 'Demo Rider';
    final offer = _current ?? _available;

    return _ScrollTab(
      slivers: [
        SliverToBoxAdapter(
          child: _OnlineHeader(
            name: name,
            online: widget.online,
            onToggle: widget.onToggleOnline,
          ),
        ),
        SliverToBoxAdapter(child: _EarningsCard(earnings: _earnings)),
        if (offer != null)
          SliverToBoxAdapter(
            child: _DeliveryOffer(
              delivery: offer,
              inProgress: _current != null,
              onAccept: () => _accept(offer),
              onDecline: _current != null
                  ? null
                  : () {
                      setState(() => _available = null);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Delivery declined.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
            ),
          ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _SectionTitle('Your day'),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          sliver: SliverToBoxAdapter(child: _DayStats()),
        ),
      ],
    );
  }
}

class _ScrollTab extends StatelessWidget {
  const _ScrollTab({required this.slivers});

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.of(context).padding.top + 8,
          ),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _OnlineHeader extends StatelessWidget {
  const _OnlineHeader({
    required this.name,
    required this.online,
    required this.onToggle,
  });

  final String name;
  final bool online;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi, $name', style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                online ? 'You’re online and ready to go' : 'You’re offline',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          _StatusPill(online: online),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: online ? RiderApp.brandGreenLight : const Color(0xFFE8EAED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? RiderApp.brandGreen : const Color(0xFF9AA1AA),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color:
                  online ? RiderApp.brandGreenDark : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// Large earnings banner (DoorDash-style).
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({this.earnings});

  final DeliveryEarnings? earnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = earnings?.totalEarnings ?? 18450;
    final count = earnings?.completedDeliveries;
    final avg = count == null || count == 0 ? null : total / count;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RiderApp.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today’s earnings',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            '${RiderApp.currencySymbol}${_formatNaira(total)}',
            style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(label: 'Deliveries',
                  value: count?.toString() ?? '12'),
              _MiniStat(label: 'Avg / trip', value: _formatNaira(avg ?? 0)),
              const _MiniStat(label: 'Rating', value: '4.9'),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatNaira(double amount) {
  final n = amount.toStringAsFixed(amount % 1 == 0 ? 0 : 0);
  final parts = n.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return parts;
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _DayStats extends StatelessWidget {
  const _DayStats();

  @override
  Widget build(BuildContext context) {
    const stats = [
      (Icons.check_circle, '12', 'Delivered', Color(0xFF16A34A)),
      (Icons.rate_review, '4.9', 'Rating', Color(0xFF2563EB)),
      (Icons.money, '18.4k', 'Gross', Color(0xFFD97706)),
    ];

    return Row(
      children: List.generate(stats.length, (index) {
        final (icon, value, label, color) = stats[index];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < stats.length - 1 ? 10 : 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RiderApp.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 8),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 18)),
                const SizedBox(height: 2),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12)),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _DeliveryOffer extends StatelessWidget {
  const _DeliveryOffer({
    this.delivery,
    this.inProgress = false,
    required this.onAccept,
    this.onDecline,
  });

  final RiderDelivery? delivery;
  final bool inProgress;
  final VoidCallback onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = delivery;
    if (d == null) {
      return const SizedBox.shrink();
    }
    final String title;
    final String pickupTitle;
    final String pickupSubtitle;
    final String dropTitle;
    title = inProgress ? d.statusLabel : 'New delivery request';
    pickupTitle = d.pickupLabel;
    pickupSubtitle =
        d.storeName.isNotEmpty ? d.storeName : d.pickupAddress;
    dropTitle = d.deliveryAddress;
    final fee = d.fee;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: inProgress ? RiderApp.ink : RiderApp.brandGreen,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StopRow(
            icon: Icons.storefront_outlined,
            title: pickupTitle,
            subtitle: pickupSubtitle,
          ),
          const SizedBox(height: 10),
          _StopRow(
            icon: Icons.home_outlined,
            title: 'Drop-off',
            subtitle: dropTitle,
          ),
          if (d.parcelInfo.isNotEmpty) ...[
            const SizedBox(height: 10),
            _StopRow(
              icon: Icons.inventory_2_outlined,
              title: 'Parcel',
              subtitle: d.parcelInfo,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Total earnings',
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9), fontSize: 13)),
              const Spacer(),
              Text('${RiderApp.currencySymbol}${_formatNaira(fee)}',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (onDecline != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Decline',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: onDecline == null ? 1 : 1,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: inProgress
                        ? RiderApp.ink
                        : RiderApp.brandGreenDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    inProgress ? 'Resume' : 'Accept',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      ),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
                child: Icon(Icons.notifications_none_rounded,
                    color: RiderApp.ink)),
            Positioned(
              right: 8,
              top: 6,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Deliveries tab
// ---------------------------------------------------------------------------

class _DeliveriesTab extends StatefulWidget {
  const _DeliveriesTab();

  @override
  State<_DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<_DeliveriesTab> {
  final DeliveryService service =
      DeliveryService(api: AuthSession.instance.api);

  List<RiderDelivery>? _deliveries;
  bool _loading = false;

  bool get _live =>
      AuthSession.instance.isAuthenticated &&
      AuthSession.instance.accessToken != 'demo.access';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthSession.instance.accessToken;
    if (token == null || token == 'demo.access') return;
    setState(() => _loading = true);
    try {
      final ds = await service.myDeliveries(token);
      if (!mounted) return;
      setState(() {
        _deliveries = ds;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = _deliveries;

    if (_live && _loading && deliveries == null) {
      return const _ScrollTab(
        slivers: [
          SliverToBoxAdapter(child: _PageTitle('Deliveries')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      );
    }

    if (_live && deliveries != null && deliveries.isEmpty) {
      return _ScrollTab(
        slivers: [
          const SliverToBoxAdapter(child: _PageTitle('Deliveries')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'No deliveries yet — requests will appear here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      );
    }

    final rows = _live && deliveries != null
        ? [
            for (final d in deliveries)
              (
                d.isActive ? 'Active' : d.statusLabel,
                '${d.pickupLabel} → ${d.deliveryAddress}',
                '${d.statusLabel} · ${RiderApp.currencySymbol}${_formatNaira(d.fee)}${d.parcelInfo.isNotEmpty ? ' · ${d.parcelInfo}' : ''}',
                d.isActive
                    ? RiderApp.brandGreen
                    : (d.status == 'delivered'
                        ? const Color(0xFF9AA1AA)
                        : const Color(0xFF2563EB)),
                d.isActive
                    ? Icons.delivery_dining_rounded
                    : (d.status == 'delivered'
                        ? Icons.check_circle_outline_rounded
                        : Icons.schedule),
                d,
              )
          ]
        : [
            (
              'Active',
              'Bamboo Bistro → Victoria Island',
              'Pickup in 8 min · ₦3,200',
              RiderApp.brandGreen,
              Icons.delivery_dining,
              null as RiderDelivery?,
            ),
            (
              'Scheduled',
              'Mother’s Kitchen → Lekki Phase 1',
              'Today 6:30 PM · ₦2,800',
              const Color(0xFF2563EB),
              Icons.schedule,
              null as RiderDelivery?,
            ),
          ];

    return _ScrollTab(
      slivers: [
        const SliverToBoxAdapter(
          child: _PageTitle('Deliveries'),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final (status, route, meta, color, icon, d) = rows[index];
              return _DeliveryCard(
                status: status,
                route: route,
                meta: meta,
                color: color,
                icon: icon,
                onTap: d == null || !d.isActive
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => NavigationScreen(delivery: d),
                          ),
                        ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.status,
    required this.route,
    required this.meta,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String status;
  final String route;
  final String meta;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RiderApp.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(route,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontSize: 15)),
                    Text(meta,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right,
                    color: Color(0xFF9AA1AA), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Earnings tab
// ---------------------------------------------------------------------------

class _EarningsTab extends StatefulWidget {
  const _EarningsTab();

  @override
  State<_EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<_EarningsTab> {
  final DeliveryService service =
      DeliveryService(api: AuthSession.instance.api);

  DeliveryEarnings? _earnings;
  List<RiderDelivery>? _deliveries;

  bool get _live =>
      AuthSession.instance.isAuthenticated &&
      AuthSession.instance.accessToken != 'demo.access';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthSession.instance.accessToken;
    if (token == null || token == 'demo.access') return;
    try {
      final earnings = await service.earnings(token);
      final ds = await service.myDeliveries(token);
      if (!mounted) return;
      setState(() {
        _earnings = earnings;
        _deliveries = ds;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return _ScrollTab(
      slivers: [
        const SliverToBoxAdapter(child: _PageTitle('Earnings')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: _EarningsSummary(
              earnings: _live ? _earnings : null,
              deliveries: _live ? _deliveries : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _EarningsSummary extends StatelessWidget {
  const _EarningsSummary({this.earnings, this.deliveries});

  final DeliveryEarnings? earnings;
  final List<RiderDelivery>? deliveries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = earnings?.totalEarnings ?? 84200;
    final count = earnings?.completedDeliveries ?? 46;
    final hours = count < 10 ? '${count}h' : '${(count * 0.5).round()}h';
    final avg = count == 0 ? 0.0 : total / count;
    final delivered = (deliveries ?? const <RiderDelivery>[])
        .where((d) => d.status == 'delivered')
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [RiderApp.brandGreenDark, RiderApp.brandGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total earnings',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white70)),
              const SizedBox(height: 6),
              Text('${RiderApp.currencySymbol}${_formatNaira(total)}',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(color: Colors.white)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _EarnStat(label: 'Deliveries', value: '$count'),
                  ),
                  Expanded(
                    child: _EarnStat(label: 'Hours', value: hours),
                  ),
                  Expanded(
                    child:
                        _EarnStat(label: 'Avg / trip', value: '${RiderApp.currencySymbol}${_formatNaira(avg)}'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Recent deliveries', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (delivered.isEmpty)
          Text(
            deliveries == null
                ? 'Payouts settle after each completed delivery.'
                : 'No completed deliveries yet.',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final d in delivered)
            _PayoutRow(
              date: 'Total',
              amount: '${RiderApp.currencySymbol}${_formatNaira(d.fee)}',
              status: 'Paid',
              subtitle: d.pickupLabel,
            ),
      ],
    );
  }
}

class _EarnStat extends StatelessWidget {
  const _EarnStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
      ],
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({
    required this.date,
    required this.amount,
    required this.status,
    this.subtitle,
  });

  final String date;
  final String amount;
  final String status;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RiderApp.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: RiderApp.brandGreenDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle ?? date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(date,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9AA1AA))),
              ],
            ),
          ),
          Text(amount,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(width: 10),
          Text(status,
              style: TextStyle(
                color:
                    status == 'Paid' ? RiderApp.brandGreen : const Color(
                        0xFFD97706),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account tab
// ---------------------------------------------------------------------------

class _AccountTab extends StatelessWidget {
  const _AccountTab();

  @override
  Widget build(BuildContext context) {
    return const _ScrollTab(
      slivers: [
        SliverToBoxAdapter(child: _PageTitle('Account')),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: _ProfileCard(),
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthSession.instance.user;
    final name = user?.name ?? 'Demo Rider';
    final email = user?.email ?? 'rider@marketgo.com';
    final initials = _initials(name);
    const entries = <(IconData, String, String, List<String>)>[
      (
        Icons.directions_bike,
        'My vehicle',
        'The vehicle you use for MarketGO deliveries.',
        ['MarketGO Bike · NG', 'Registered: Jun 2026'],
      ),
      (
        Icons.shield_outlined,
        'Insurance & docs',
        'Your insurance and rider documents are reviewed when you upload them.',
        [],
      ),
      (
        Icons.account_balance_rounded,
        'Bank Accounts',
        'Manage your bank details for withdrawals',
        [],
      ),
      (
        Icons.payments_rounded,
        'Withdraw Earnings',
        'Request a payout to your bank account',
        [],
      ),
      (
        Icons.delivery_dining_rounded,
        'Delivery addresses',
        'Saved delivery addresses for your profile',
        [],
      ),
      (
        Icons.credit_card_rounded,
        'Payment methods',
        'Saved payment methods on this device',
        [],
      ),
      (
        Icons.favorite_border_rounded,
        'Favourites',
        'Stores and products you bookmarked',
        [],
      ),
      (
        Icons.help_outline,
        'Help & support',
        'Support is available around the clock for riders.',
        [],
      ),
      (Icons.logout, 'Sign out', '', []),
    ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: RiderApp.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: RiderApp.brandGreenLight,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: RiderApp.brandGreenDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(email,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Text('MarketGO Bike · NG', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 4),
                  Text('4.9 rating', style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: RiderApp.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++)
                InkWell(
                  onTap: () {
                    if (entries[i].$1 == Icons.logout) {
                      _confirmLogout(context);
                      return;
                    }
                    if (entries[i].$1 == Icons.account_balance_rounded) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BankAccountScreen(),
                        ),
                      );
                      return;
                    }
                    if (entries[i].$1 == Icons.payments_rounded) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WithdrawalScreen(),
                        ),
                      );
                      return;
                    }
                    if (entries[i].$1 == Icons.delivery_dining_rounded) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DeliveryAddressesScreen(),
                        ),
                      );
                      return;
                    }
                    if (entries[i].$1 == Icons.credit_card_rounded) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PaymentMethodsScreen(),
                        ),
                      );
                      return;
                    }
                    if (entries[i].$1 == Icons.favorite_border_rounded) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FavouritesScreen(),
                        ),
                      );
                      return;
                    }
                    if (entries[i].$1 == Icons.help_outline) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const HelpScreen(),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => InfoScreen(
                          title: entries[i].$2,
                          icon: entries[i].$1,
                          description: entries[i].$3,
                          bullets: entries[i].$4,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(entries[i].$1,
                            color: entries[i].$1 == Icons.logout
                                ? const Color(0xFFEF4444)
                                : RiderApp.brandGreenDark),
                        const SizedBox(width: 14),
                        Text(entries[i].$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        const Icon(Icons.chevron_right, size: 20,
                            color: Color(0xFF9AA1AA)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, size: 40, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text('Sign out of MarketGO?',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('You’ll stop receiving delivery requests.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444)),
                  onPressed: () {
                    AuthSession.instance.logOut();
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text('Sign Out'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}

String _initials(String name) {
  final parts =
      name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'DR';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
