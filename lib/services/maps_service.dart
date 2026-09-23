import 'api_client.dart';

/// Public map configuration served by `/api/v1/settings`. Secret provider keys
/// are never exposed — only what the client apps need to render maps.
class MapConfig {
  const MapConfig({
    this.provider = 'none',
    this.googleJsKey = '',
    this.mapboxPublicToken = '',
    this.mapboxStyle = 'streets-v12',
    this.leafletTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.leafletAttribution = '&copy; OpenStreetMap contributors',
    this.defaultZoom = 16,
  });

  final String provider; // google | mapbox | leaflet | none
  final String googleJsKey;
  final String mapboxPublicToken;
  final String mapboxStyle;
  final String leafletTileUrl;
  final String leafletAttribution;
  final int defaultZoom;

  bool get isGoogle => provider == 'google' && googleJsKey.isNotEmpty;
  bool get isMapbox => provider == 'mapbox' && mapboxPublicToken.isNotEmpty;
  bool get isLeaflet => provider == 'leaflet';
  bool get isEnabled => provider != 'none';

  factory MapConfig.fromJson(Map<String, dynamic> json) {
    return MapConfig(
      provider: (json['provider'] as String?) ?? 'none',
      googleJsKey: (json['google_js_key'] as String?) ?? '',
      mapboxPublicToken: (json['mapbox_public_token'] as String?) ?? '',
      mapboxStyle: (json['mapbox_style'] as String?) ?? 'streets-v12',
      leafletTileUrl: (json['leaflet_tile_url'] as String?) ??
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      leafletAttribution: (json['leaflet_attribution'] as String?) ??
          '&copy; OpenStreetMap contributors',
      defaultZoom: (json['default_zoom'] as num?)?.toInt() ?? 16,
    );
  }
}

/// A single geocoded address result from `GET /api/v1/search/places`.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.label,
    required this.secondary,
    required this.latitude,
    required this.longitude,
  });

  final String placeId;
  final String label;
  final String secondary;
  final double latitude;
  final double longitude;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: (json['place_id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      secondary: (json['secondary'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Talks to the marketgo-api addresses/places proxy. Server-side provider keys
/// stay on the backend; this client only ever sends free-text queries.
class MapsService {
  MapsService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Future<MapConfig> fetchConfig() async {
    try {
      final data = await api.get('/api/v1/settings');
      final map = data['map'];
      if (map is Map<String, dynamic>) {
        return MapConfig.fromJson(map);
      }
    } catch (_) {
      // Fall through to the disabled config (plain text addresses).
    }
    return const MapConfig();
  }

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final params = Uri(queryParameters: {'q': trimmed, 'limit': '6'}).query;
    try {
      final data = await api.get('/api/v1/search/places?$params');
      final list = data['places'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(PlaceSuggestion.fromJson)
            .toList();
      }
    } catch (_) {
      // Silent — the search field treats this as "no suggestions".
    }
    return const [];
  }
}