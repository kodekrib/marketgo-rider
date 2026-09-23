import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Global switch so widget tests can keep frames stable.
/// Disable in tests (set to false) to avoid never-ending pumpAndSettle loops.
bool kRouteAnimationEnabled = true;

/// Animated delivery backdrop for the login hero band.
///
/// Draws a subtle "street map" of dashed roads plus an animated vehicle that
/// continuously rides along the main route. The roads are static; only the
/// vehicle (an [Icon]) travels, so it reads as a courier in motion behind the
/// brand mark.
class AnimatedRouteBackdrop extends StatefulWidget {
  const AnimatedRouteBackdrop({
    super.key,
    required this.vehicleIcon,
    this.duration = const Duration(seconds: 9),
  });

  final IconData vehicleIcon;
  final Duration duration;

  @override
  State<AnimatedRouteBackdrop> createState() => _AnimatedRouteBackdropState();
}

class _AnimatedRouteBackdropState extends State<AnimatedRouteBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (kRouteAnimationEnabled) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final w = size.width;
        final h = size.height;

        final route = <Offset>[
          Offset(-0.06 * w, 0.20 * h),
          Offset(0.30 * w, 0.44 * h),
          Offset(0.58 * w, 0.30 * h),
          Offset(0.80 * w, 0.52 * h),
          Offset(1.06 * w, 0.46 * h),
        ];

        final lanes = <List<Offset>>[
          [
            Offset(-0.12 * w, 0.86 * h),
            Offset(0.30 * w, 0.60 * h),
            Offset(0.62 * w, 0.76 * h),
            Offset(0.95 * w, 0.58 * h),
          ],
          [
            Offset(0.92 * w, -0.04 * h),
            Offset(0.66 * w, 0.26 * h),
            Offset(0.42 * w, 0.18 * h),
          ],
          [
            Offset(0.90 * w, 0.32 * h),
            Offset(0.64 * w, 0.46 * h),
            Offset(0.48 * w, 0.66 * h),
          ],
        ];

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _RoadsPainter(size: size, route: route, lanes: lanes),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final (offset: pos, angle: heading) =
                    _pointAlong(route, _controller.value);
                return Positioned(
                  left: pos.dx - 16,
                  top: pos.dy - 16,
                  child: Transform.rotate(
                    angle: heading,
                    child: Icon(
                      widget.vehicleIcon,
                      size: 32,
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black26, blurRadius: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Walks a polyline and returns the point + heading for progress t in [0,1].
({Offset offset, double angle}) _pointAlong(List<Offset> nodes, double t) {
  if (nodes.length < 2) {
    return (offset: nodes.isEmpty ? Offset.zero : nodes.first, angle: 0);
  }

  final segments = <double>[];
  var total = 0.0;
  for (var i = 0; i < nodes.length - 1; i++) {
    final d = (nodes[i + 1] - nodes[i]).distance;
    segments.add(d);
    total += d;
  }

  var remaining = t.clamp(0.0, 1.0) * total;
  for (var i = 0; i < segments.length; i++) {
    if (remaining <= segments[i]) {
      final a = nodes[i];
      final b = nodes[i + 1];
      final local = segments[i] == 0 ? 0.0 : remaining / segments[i];
      return (
        offset: Offset(
          a.dx + (b.dx - a.dx) * local,
          a.dy + (b.dy - a.dy) * local,
        ),
        angle: math.atan2(b.dy - a.dy, b.dx - a.dx),
      );
    }
    remaining -= segments[i];
  }

  final a = nodes[nodes.length - 2];
  final b = nodes[nodes.length - 1];
  return (offset: b, angle: math.atan2(b.dy - a.dy, b.dx - a.dx));
}

/// Paints faint dashed roads and "building block" shapes for the map motif.
class _RoadsPainter extends CustomPainter {
  _RoadsPainter({
    required this.size,
    required this.route,
    required this.lanes,
  });

  final Size size;
  final List<Offset> route;
  final List<List<Offset>> lanes;

  static const double _dash = 6;
  static const double _gap = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = Colors.white.withOpacity(0.16);
    final blockPaint = Paint()..color = Colors.white.withOpacity(0.05);

    void dashed(List<Offset> pts) {
      for (var i = 0; i < pts.length - 1; i++) {
        final from = pts[i];
        final to = pts[i + 1];
        final total = (to - from).distance;
        final dir = (to - from) / total;
        var d = 0.0;
        while (d < total) {
          final start = from + dir * d;
          final end = from + dir * (d + _dash).clamp(0, total);
          canvas.drawLine(start, end, roadPaint);
          d += _dash + _gap;
        }
      }
      for (final p in pts) {
        canvas.drawCircle(p, 4, dotPaint);
      }
    }

    for (final lane in lanes) {
      dashed(lane);
    }
    dashed(route);

    // City blocks scattered off the main roads.
    for (final rect in [
      Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.11, h * 0.17),
      Rect.fromLTWH(w * 0.36, h * 0.10, w * 0.08, h * 0.10),
      Rect.fromLTWH(w * 0.78, h * 0.66, w * 0.14, h * 0.24),
      Rect.fromLTWH(w * 0.18, h * 0.68, w * 0.10, h * 0.12),
      Rect.fromLTWH(w * 0.10, h * 0.38, w * 0.07, h * 0.09),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        blockPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoadsPainter oldDelegate) =>
      oldDelegate.size != size;
}