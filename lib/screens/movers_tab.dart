import 'package:flutter/material.dart';
import '../app.dart';
import '../services/auth_service.dart';
import '../services/mover_service.dart';
import 'accept_mover_job_screen.dart';
import 'mover_job_manage_screen.dart';
import 'mover_vehicles_screen.dart';

/// Movers tab — the ride-share style marketplace for heavy moving jobs.
class MoversTab extends StatefulWidget {
  const MoversTab({super.key, required this.service});

  final MoverService service;

  @override
  State<MoversTab> createState() => _MoversTabState();
}

class _MoversTabState extends State<MoversTab> {
  List<MoverJob>? _available;
  MoverJob? _current;
  MoverEarnings? _earnings;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthSession.instance.accessToken;
    if (token == null) return;
    if (token == 'demo.access') {
      setState(() {
        _available = MoverService.demoJobs();
        _current = null;
        _earnings = const MoverEarnings(
            completedJobs: 4, totalEarnings: 96000, currency: 'NGN');
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final available = await widget.service.available(token);
      final current = await widget.service.current(token);
      final earnings = await widget.service.earnings(token);
      if (!mounted) return;
      setState(() {
        _available = available;
        _current = current;
        _earnings = earnings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openAccept(MoverJob job) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => AcceptMoverJobScreen(
              service: widget.service,
              job: job,
              onAccepted: () {
                _load();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Move accepted — start heading to pickup.'),
                    behavior: SnackBarBehavior.floating));
              },
            ),
          ),
        )
        .then((_) => _load());
  }

  void _openManage(MoverJob job) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => MoverJobManageScreen(
              service: widget.service,
              job: job,
              onChanged: () {},
            ),
          ),
        )
        .then((_) => _load());
  }

  void _openVehicles() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (_) => MoverVehiclesScreen(service: widget.service),
        ))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;

    return _ScrollTab(
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            onVehicles: _openVehicles,
            earnings: _earnings,
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ),
          )
        else ...[
          if (current != null) ...[
            const SliverToBoxAdapter(child: _SectionTitle('Current move')),
            SliverToBoxAdapter(
              child: _CurrentJobCard(
                job: current,
                onTap: () => _openManage(current),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: _SectionTitle('Available moves')),
          if (_available == null || _available!.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyMoves(onVehicles: _openVehicles),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _AvailableJobCard(
                  job: _available![i],
                  onTap: () => _openAccept(_available![i]),
                  last: i == _available!.length - 1,
                ),
                childCount: _available!.length,
              ),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
          child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onVehicles, required this.earnings});

  final VoidCallback onVehicles;
  final MoverEarnings? earnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = earnings?.totalEarnings ?? 0;
    final completed = earnings?.completedJobs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Movers', style: theme.textTheme.headlineMedium),
                  Text('Heavy moves near you',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
              const Spacer(),
              IconButton.filled(
                onPressed: onVehicles,
                style: IconButton.styleFrom(
                  backgroundColor: RiderApp.brandGreenLight,
                  foregroundColor: RiderApp.brandGreenDark,
                ),
                tooltip: 'My vehicles',
                icon: const Icon(Icons.fire_truck_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RiderApp.ink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Moving earnings',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 4),
                Text('${RiderApp.currencySymbol}${_naira(total)}',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: Colors.white)),
                if (completed != null) ...[
                  const SizedBox(height: 8),
                  Text('$completed moves completed',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white54, fontSize: 12)),
                ],
              ],
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _CurrentJobCard extends StatelessWidget {
  const _CurrentJobCard({required this.job, required this.onTap});

  final MoverJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RiderApp.brandGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sailing_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Move #${job.id} · ${job.statusLabel}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
              const SizedBox(height: 10),
              Text(job.pickupAddress,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              Text('${job.deliveryAddress} · ${job.itemCount} items',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableJobCard extends StatelessWidget {
  const _AvailableJobCard({
    required this.job,
    required this.onTap,
    required this.last,
  });

  final MoverJob job;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, last ? 4 : 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RiderApp.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E5EA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: RiderApp.brandGreenLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      moverVehicleLabel(job.vehicleType),
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: RiderApp.brandGreenDark),
                    ),
                  ),
                  const Spacer(),
                  Text('${job.itemCount} items',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.trip_origin_rounded,
                      size: 16, color: RiderApp.brandGreenDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(job.pickupAddress,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 7),
                child: Container(height: 14, width: 2, color: const Color(0xFFE2E5EA)),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(job.deliveryAddress,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              if (job.extraPackers > 0) ...[
                const SizedBox(height: 8),
                Text('${job.extraPackers} extra packer(s) requested',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RiderApp.brandGreen,
                  ),
                  onPressed: onTap,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Accept & quote'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMoves extends StatelessWidget {
  const _EmptyMoves({required this.onVehicles});

  final VoidCallback onVehicles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RiderApp.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5EA)),
      ),
      child: Column(
        children: [
          Icon(Icons.tour_rounded, color: RiderApp.brandGreen, size: 36),
          const SizedBox(height: 12),
          Text('No moves available',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'New moving requests appear here — make sure you have a vehicle '
            'registered to get offered matching jobs.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onVehicles,
            icon: const Icon(Icons.fire_truck_outlined, size: 18),
            label: const Text('Manage my vehicles'),
          ),
        ],
      ),
    );
  }
}

String _naira(double value) {
  final n = value.round().toString();
  final formatted = n.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return formatted;
}