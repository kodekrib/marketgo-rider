import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../app.dart';
import '../services/auth_service.dart';
import '../services/delivery_service.dart';
import '../widgets/live_map.dart';

/// Rider-facing navigation screen that shows the route from the pickup to the
/// customer's drop-off address.
///
/// When opened with (or able to load) a real delivery it streams the rider's
/// simulated position to the backend every few seconds via
/// PATCH /api/v1/rider/deliveries/:id/location so the customer's tracking
/// screen can follow along, and moves the delivery through the rider status
/// pipeline (picked_up → in_transit → delivered).
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, this.delivery});

  final RiderDelivery? delivery;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  DeliveryService service = DeliveryService(api: AuthSession.instance.api);
  RiderDelivery? _delivery;
  Timer? _locationTimer;
  double _progress = 0;
  bool _busy = false;
  bool _demoLocalPickedUp = false;

  @override
  void initState() {
    super.initState();
    final token = AuthSession.instance.accessToken;
    if (token == null || token == 'demo.access') return;
    if (widget.delivery != null) {
      _delivery = widget.delivery;
      _startLocationStream(token, widget.delivery!);
    } else {
      _loadCurrent(token);
    }
  }

  Future<void> _loadCurrent(String token) async {
    try {
      final d = await service.current(token);
      if (!mounted) return;
      setState(() => _delivery = d);
      if (d != null && d.isActive) _startLocationStream(token, d);
    } catch (_) {}
  }

  /// Simulates the rider moving along the route and pushes each GPS fix up.
  void _startLocationStream(String token, RiderDelivery d) {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      _progress = (_progress + 5 / 300).clamp(0.0, 1.0);
      final position = simulatedRider(d).position;
      if (!mounted) return;
      setState(() {});
      try {
        await service.updateLocation(token, d.id, position.latitude,
            position.longitude);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  bool get _live =>
      AuthSession.instance.isAuthenticated &&
      AuthSession.instance.accessToken != 'demo.access';

  LatLng _pickup(RiderDelivery? d) {
    if (d != null && d.pickupLat != null && d.pickupLng != null) {
      return LatLng(d.pickupLat!, d.pickupLng!);
    }
    return LagosLocations.vendorHub;
  }

  LatLng _dropoff(RiderDelivery? d) {
    if (d != null && d.deliveryLat != null && d.deliveryLng != null) {
      return LatLng(d.deliveryLat!, d.deliveryLng!);
    }
    return LagosLocations.lekki;
  }

  SimulatedRider simulatedRider(RiderDelivery? d) {
    return SimulatedRider(
      id: 'me',
      name: 'You',
      color: RiderApp.brandGreen,
      route: buildRoute(_pickup(d), _dropoff(d)),
      progress: _progress,
    );
  }

  String get _pickupLabel {
    final d = _delivery;
    if (d == null) return 'Vendor Hub, Lagos';
    return d.pickupLabel;
  }

  String get _dropoffLabel {
    final d = _delivery;
    if (d == null) return '12 Admiralty Way, Lekki';
    return d.deliveryAddress;
  }

  Future<void> _advanceStatus() async {
    final d = _delivery;
    final token = AuthSession.instance.accessToken;
    if (token == null) return;
    if (_live && d != null && d.isActive) {
      final next = _nextStatus(d.status);
      if (next == null) {
        _completeLocally();
        return;
      }
      setState(() => _busy = true);
      try {
        await service.updateStatus(token, d.id, next);
        if (!mounted) return;
        setState(() {
          _delivery = RiderDelivery(
            id: d.id,
            type: d.type,
            status: next,
            pickupAddress: d.pickupAddress,
            deliveryAddress: d.deliveryAddress,
            phone: d.phone,
            packageDetails: d.packageDetails,
            fee: d.fee,
            customerName: d.customerName,
            storeName: d.storeName,
            riderName: d.riderName,
            weightKg: d.weightKg,
            pickupLat: d.pickupLat,
            pickupLng: d.pickupLng,
            deliveryLat: d.deliveryLat,
            deliveryLng: d.deliveryLng,
            estimatedTime: d.estimatedTime,
          );
          _busy = false;
        });
        if (next == 'delivered') {
          _locationTimer?.cancel();
          _completeLocally();
        } else {
          _toast(next == 'picked_up'
              ? 'Picked up — head to the drop-off.'
              : 'Marked as $next.');
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update delivery: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      _advanceLocal();
    }
  }

  void _advanceLocal() {
    if (!_demoLocalPickedUp) {
      setState(() => _demoLocalPickedUp = true);
      _toast('Picked up — head to the drop-off.');
      return;
    }
    _completeLocally();
  }

  void _completeLocally() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery completed. Thank you!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _locationTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String? _nextStatus(String status) {
    switch (status) {
      case 'accepted':
      case 'pending':
        return 'picked_up';
      case 'picked_up':
        return 'in_transit';
      case 'in_transit':
        return 'delivered';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _delivery;
    final next = d == null ? 'picked_up' : (_nextStatus(d.status) ?? 'delivered');
    final nextLabel = d == null || !d.isActive
        ? (_demoLocalPickedUp ? 'Mark as Delivered' : 'Mark as Picked Up')
        : _buttonLabel(next);

    return Scaffold(
      body: Stack(
        children: [
          LiveMap(
            riders: [simulatedRider(d)],
            pickup: _pickup(d),
            dropoff: _dropoff(d),
            title: d == null || !d.isActive
                ? 'Navigate to drop-off'
                : d.statusLabel,
            subtitle: _dropoffLabel,
            initialZoom: 13,
            centerOn: LagosLocations.victoriaIsland,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            child: _BackButton(),
          ),
          if (d != null && d.estimatedTime != null && d.isActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 12,
              child: _EtaPill(
                eta: 'Est. arrival ${_formatTime(d.estimatedTime!)}',
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _DeliveryActionCard(
              pickups: _pickupLabel,
              dropoff: _dropoffLabel,
              parcel: d?.parcelInfo.isEmpty ?? true ? null : d!.parcelInfo,
              nextLabel: nextLabel,
              busy: _busy,
              onPressed: _advanceStatus,
            ),
          ),
        ],
      ),
    );
  }

  String _buttonLabel(String next) {
    switch (next) {
      case 'picked_up':
        return 'Mark as Picked Up';
      case 'in_transit':
        return 'Start Trip';
      case 'delivered':
        return 'Mark as Delivered';
      default:
        return 'Continue';
    }
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111418)),
        ),
      ),
    );
  }
}

class _EtaPill extends StatelessWidget {
  const _EtaPill({required this.eta});

  final String eta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(eta, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _DeliveryActionCard extends StatelessWidget {
  const _DeliveryActionCard({
    required this.pickups,
    required this.dropoff,
    this.parcel,
    required this.nextLabel,
    required this.busy,
    required this.onPressed,
  });

  final String pickups;
  final String dropoff;
  final String? parcel;
  final String nextLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StopInfo(
                  icon: Icons.storefront_outlined,
                  title: 'Pick-up',
                  address: pickups,
                  color: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StopInfo(
                  icon: Icons.home_outlined,
                  title: 'Drop-off',
                  address: dropoff,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (parcel != null && parcel!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 16, color: Color(0xFF5B616A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(parcel!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF5B616A))),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: busy ? null : onPressed,
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(nextLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopInfo extends StatelessWidget {
  const _StopInfo({
    required this.icon,
    required this.title,
    required this.address,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String address;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5B616A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111418),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}