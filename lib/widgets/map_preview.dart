import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as ll;

import '../services/google_maps_loader.dart';
import '../services/maps_service.dart';

/// Tiny provider-aware map preview pinned at a chosen location.
///
/// * Google provider (web): interactive Google Maps SDK driven by the runtime
///   key from the admin settings (the JS script is injected on demand).
/// * Mapbox: flutter_map against the Mapbox tiles + public token.
/// * Leaflet / default: flutter_map against the configured tile URL.
///
/// Google Maps is only rendered on web; elsewhere (where a native API key
/// would need platform config) it falls back to the tile layer.
class MapPreview extends StatelessWidget {
  const MapPreview({
    super.key,
    required this.config,
    required this.latitude,
    required this.longitude,
    this.zoom,
    this.height = 180,
    this.placeholder = const SizedBox.shrink(),
  });

  final MapConfig config;
  final double latitude;
  final double longitude;
  final double? zoom;
  final double height;
  final Widget placeholder;

  double get _zoom => zoom ?? config.defaultZoom.toDouble();

  @override
  Widget build(BuildContext context) {
    final target = _target();
    if (target == null) return placeholder;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: target,
      ),
    );
  }

  Widget? _target() {
    if (config.isGoogle && kIsWeb) {
      return _GooglePinnedMap(
        key: ValueKey('gm-${config.googleJsKey.hashCode}'),
        apiKey: config.googleJsKey,
        latitude: latitude,
        longitude: longitude,
        zoom: _zoom,
      );
    }

    final tileUrl = config.isMapbox
        ? 'https://api.mapbox.com/styles/v1/mapbox/${config.mapboxStyle}/tiles/256/{z}/{x}/{y}@2x?access_token=${Uri.encodeQueryComponent(config.mapboxPublicToken)}'
        : config.isGoogle && !kIsWeb
            ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
            : config.isEnabled
                ? config.leafletTileUrl
                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    final attribution = config.isMapbox
        ? '&copy; Mapbox &copy; OpenStreetMap'
        : config.leafletAttribution;

    return FlutterMap(
      options: MapOptions(
        initialCenter: ll.LatLng(latitude, longitude),
        initialZoom: _zoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          userAgentPackageName: 'com.marketgo.app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: ll.LatLng(latitude, longitude),
              width: 40,
              height: 40,
              child: const _Pin(),
            ),
          ],
        ),
        SimpleAttributionWidget(
          source: Text(
            attribution,
            style: const TextStyle(fontSize: 10, color: Color(0x99000000)),
          ),
          onTap: () {},
        ),
      ],
    );
  }
}

class _GooglePinnedMap extends StatefulWidget {
  const _GooglePinnedMap({
    super.key,
    required this.apiKey,
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final String apiKey;
  final double latitude;
  final double longitude;
  final double zoom;

  @override
  State<_GooglePinnedMap> createState() => _GooglePinnedMapState();
}

class _GooglePinnedMapState extends State<_GooglePinnedMap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ensureGoogleMaps(widget.apiKey);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: gm.LatLng(widget.latitude, widget.longitude),
        zoom: widget.zoom,
      ),
      markers: {
        gm.Marker(
          markerId: const gm.MarkerId('pin'),
          position: gm.LatLng(widget.latitude, widget.longitude),
        ),
      },
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: true,
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Icon(
      Icons.location_on_rounded,
      size: 40,
      color: color,
      shadows: const [
        Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );
  }
}