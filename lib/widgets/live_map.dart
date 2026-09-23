import 'dart:math' show sin, cos, atan2, sqrt;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Coordinates for Lagos demo area.
class LagosLocations {
  static const LatLng vendorHub = LatLng(6.5244, 3.3792);
  static const LatLng lekki = LatLng(6.4466, 3.4723);
  static const LatLng victoriaIsland = LatLng(6.4281, 3.4219);
  static const LatLng ikeja = LatLng(6.6018, 3.3515);
  static const LatLng yaba = LatLng(6.5095, 3.3711);
}

/// A simulated live rider that moves along a polyline.
class SimulatedRider {
  final String id;
  final String name;
  final List<LatLng> route;
  double progress;
  final Color color;

  SimulatedRider({
    required this.id,
    required this.name,
    required this.route,
    this.progress = 0.0,
    this.color = Colors.blue,
  });

  LatLng get position {
    if (route.length < 2) return route.first;
    final total = route.length - 1;
    final segment = (progress * total).floor().clamp(0, total - 1);
    final local = (progress * total) - segment;
    final a = route[segment];
    final b = route[segment + 1];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * local,
      a.longitude + (b.longitude - a.longitude) * local,
    );
  }
}

/// Shared live map widget used by customer, rider and can be adapted for admin.
///
/// [riders] are animated automatically. [pickup] and [dropoff] pins are shown
/// when provided. [centerOn] controls the initial camera focus.
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    required this.riders,
    this.pickup,
    this.dropoff,
    this.title,
    this.subtitle,
    this.showTileLayer = true,
    this.initialZoom = 13.0,
    this.centerOn,
  });

  final List<SimulatedRider> riders;
  final LatLng? pickup;
  final LatLng? dropoff;
  final String? title;
  final String? subtitle;
  final bool showTileLayer;
  final double initialZoom;
  final LatLng? centerOn;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.centerOn ??
        (widget.riders.isNotEmpty
            ? widget.riders.first.position
            : LagosLocations.vendorHub);

    final markers = <Marker>[
      if (widget.pickup != null)
        _pinMarker(widget.pickup!, Colors.green, Icons.storefront_outlined),
      if (widget.dropoff != null)
        _pinMarker(widget.dropoff!, Colors.red, Icons.home_outlined),
      for (final rider in widget.riders)
        Marker(
          width: 48,
          height: 48,
          point: rider.position,
          child: _RiderMarker(name: rider.name, color: rider.color),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: widget.initialZoom,
            ),
            children: [
              if (widget.showTileLayer)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.marketgo.app',
                ),
              MarkerLayer(markers: markers),
              if (widget.riders.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (final rider in widget.riders)
                      Polyline(
                        points: rider.route,
                        color: rider.color.withOpacity(0.5),
                        strokeWidth: 4,
                      ),
                  ],
                ),
            ],
          ),
          if (widget.title != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _MapHeader(title: widget.title!, subtitle: widget.subtitle),
            ),
        ],
      ),
    );
  }

  Marker _pinMarker(LatLng point, Color color, IconData icon) {
    return Marker(
      width: 44,
      height: 44,
      point: point,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF111418),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5B616A),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderMarker extends StatelessWidget {
  const _RiderMarker({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Utility to build a simple curved-ish route between two points.
List<LatLng> buildRoute(LatLng from, LatLng to, {int points = 40}) {
  final route = <LatLng>[];
  for (var i = 0; i <= points; i++) {
    final t = i / points;
    // Add a slight curve using a sine offset.
    final offset = sin(t * pi) * 0.004;
    route.add(
      LatLng(
        from.latitude + (to.latitude - from.latitude) * t + offset,
        from.longitude + (to.longitude - from.longitude) * t,
      ),
    );
  }
  return route;
}

/// Approximate distance in kilometers between two coordinates.
double distanceKm(LatLng a, LatLng b) {
  const earthRadius = 6371.0;
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLon = _toRadians(b.longitude - a.longitude);
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);
  final x = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(x), sqrt(1 - x));
  return earthRadius * c;
}

double _toRadians(double degrees) => degrees * pi / 180;
