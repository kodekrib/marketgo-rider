import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../app.dart';
import '../services/auth_service.dart';
import '../services/mover_service.dart';
import '../widgets/live_map.dart';

/// Manage an active moving job — progress it through the runtime pipeline and
/// cancel if necessary.
class MoverJobManageScreen extends StatefulWidget {
  const MoverJobManageScreen({
    super.key,
    required this.service,
    required this.job,
    this.onChanged,
  });

  final MoverService service;
  final MoverJob job;
  final VoidCallback? onChanged;

  @override
  State<MoverJobManageScreen> createState() => _MoverJobManageScreenState();
}

class _MoverJobManageScreenState extends State<MoverJobManageScreen> {
  late MoverJob _job;
  bool _busy = false;
  String? _error;
  Timer? _locationTimer;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    final token = AuthSession.instance.accessToken;
    if (token != null && token != 'demo.access' && _job.isActive) {
      _startLocationStream(token);
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  /// Simulates the mover travelling between pickup and delivery and pushes
  /// each GPS fix to the backend so live tracking can follow along.
  void _startLocationStream(String token) {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      _progress = (_progress + 5 / 300).clamp(0.0, 1.0);
      final position = _simulated().position;
      try {
        await widget.service
            .updateLocation(token, _job.id, position.latitude, position.longitude);
      } catch (_) {}
    });
  }

  SimulatedRider _simulated() {
    return SimulatedRider(
      id: 'me',
      name: 'You',
      color: RiderApp.brandGreen,
      route: buildRoute(_pickup(), _dropoff()),
      progress: _progress,
    );
  }

  LatLng _pickup() {
    if (_job.pickupLat != null && _job.pickupLng != null) {
      return LatLng(_job.pickupLat!, _job.pickupLng!);
    }
    return LagosLocations.vendorHub;
  }

  LatLng _dropoff() {
    if (_job.deliveryLat != null && _job.deliveryLng != null) {
      return LatLng(_job.deliveryLat!, _job.deliveryLng!);
    }
    return LagosLocations.lekki;
  }

  Future<void> _advance() async {
    final next = _job.nextStatus;
    if (next == null) return;
    final token = AuthSession.instance.accessToken ?? '';
    if (token == 'demo.access') {
      setState(() => _job = _copyWith(next));
      widget.onChanged?.call();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.updateStatus(token, _job.id, next);
      if (!mounted) return;
      setState(() {
        _job = _copyWith(next);
        _busy = false;
      });
      if (next == 'delivered') _locationTimer?.cancel();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  MoverJob _copyWith(String status) {
    return MoverJob(
      id: _job.id,
      customerId: _job.customerId,
      riderId: _job.riderId,
      vehicleType: _job.vehicleType,
      pickupAddress: _job.pickupAddress,
      deliveryAddress: _job.deliveryAddress,
      description: _job.description,
      itemCount: _job.itemCount,
      extraPackers: _job.extraPackers,
      packerPrice: _job.packerPrice,
      totalPackerFee: _job.totalPackerFee,
      quotedPrice: _job.quotedPrice,
      platformFee: _job.platformFee,
      totalAmount: _job.totalAmount,
      status: status,
      cancelReason: _job.cancelReason,
      customerName: _job.customerName,
      customerPhone: _job.customerPhone,
      riderName: _job.riderName,
      riderPhone: _job.riderPhone,
      vehicleName: _job.vehicleName,
      createdAt: _job.createdAt,
      pickupLat: _job.pickupLat,
      pickupLng: _job.pickupLng,
      deliveryLat: _job.deliveryLat,
      deliveryLng: _job.deliveryLng,
    );
  }

  Future<void> _cancel() async {
    final reason = await _askReason();
    if (reason == null) return;
    final token = AuthSession.instance.accessToken ?? '';
    if (token == 'demo.access') {
      setState(() => _job = _copyWith('cancelled'));
      widget.onChanged?.call();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.cancel(token, _job.id, reason);
      if (!mounted) return;
      _locationTimer?.cancel();
      setState(() {
        _job = _copyWith('cancelled');
        _busy = false;
      });
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel move?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Customer not available',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep move'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Cancel move',
                style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Move #${_job.id}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: RiderApp.ink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_job.statusLabel,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 6),
                  Text(
                    '${_job.customerName} · ${_job.customerPhone}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  if (_job.quotedPrice > 0)
                    Row(
                      children: [
                        const Text('Quote',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const Spacer(),
                        Text(_naira(_job.quotedPrice),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ],
                    ),
                  if (_job.totalAmount > 0)
                    Row(
                      children: [
                        const Text('Customer total incl. fees',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const Spacer(),
                        Text(_naira(_job.totalAmount),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _RouteCard(job: _job),
            const SizedBox(height: 20),
            Text('Progress', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            _ProgressTimeline(status: _job.status),
            if (_job.cancelReason.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Cancelled: ${_job.cancelReason}',
                  style: const TextStyle(color: Color(0xFFDC2626))),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFB3261E), fontSize: 13)),
            ],
            if (_job.isActive) ...[
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _advance,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(_job.nextButtonLabel),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _busy ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                  child: const Text('Cancel move'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.job});

  final MoverJob job;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RiderApp.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stop(Icons.trip_origin_rounded, 'Pickup', job.pickupAddress,
              RiderApp.brandGreenDark),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(height: 18, width: 2, color: const Color(0xFFE2E5EA)),
          ),
          _stop(Icons.location_on_rounded, 'Delivery', job.deliveryAddress,
              const Color(0xFFDC2626)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _meta(Icons.sailing_outlined, moverVehicleLabel(job.vehicleType)),
              _meta(Icons.inventory_2_outlined, '${job.itemCount} items'),
              if (job.extraPackers > 0)
                _meta(Icons.groups_outlined,
                    '${job.extraPackers} extra packers'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stop(IconData icon, String title, String address, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9AA1AA))),
              Text(address,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _meta(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RiderApp.brandGreenLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: RiderApp.brandGreenDark),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ProgressTimeline extends StatelessWidget {
  const _ProgressTimeline({required this.status});

  final String status;

  static const _steps = [
    ('pending', 'Requested'),
    ('accepted', 'Accepted'),
    ('en_route', 'On the way'),
    ('arrived', 'Arrived'),
    ('loading', 'Loading'),
    ('in_transit', 'In transit'),
    ('delivered', 'Delivered'),
  ];

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('This move was cancelled.',
                style: TextStyle(
                    color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    final current = _steps.indexWhere((s) => s.$1 == status);
    return Column(
      children: List.generate(_steps.length, (i) {
        final (_, label) = _steps[i];
        final done = i <= current;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor:
                      done ? RiderApp.brandGreen : const Color(0xFFE2E5EA),
                  child: Icon(
                    i == current
                        ? Icons.radio_button_checked
                        : (done ? Icons.check : Icons.radio_button_unchecked),
                    size: 16,
                    color: done ? Colors.white : const Color(0xFFC9CDD4),
                  ),
                ),
                if (i < _steps.length - 1)
                  Container(
                    width: 2,
                    height: 22,
                    color: i < current
                        ? RiderApp.brandGreen
                        : const Color(0xFFE2E5EA),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: EdgeInsets.only(
                  top: 6, bottom: i < _steps.length - 1 ? 4 : 0),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                  color: done ? RiderApp.ink : const Color(0xFF9AA1AA),
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

String _naira(double value) {
  final n = value.round().toString();
  final formatted = n.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '${RiderApp.currencySymbol}$formatted';
}