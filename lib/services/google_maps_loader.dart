/// Loads the Google Maps JavaScript API at runtime using [apiKey].
///
/// Web: the implementation at [google_maps_loader_web] injects the Maps JS
/// script on demand and shares one in-flight load across all callers. Native
/// builds (Android/iOS) use [google_maps_loader_io], where the SDK is
/// configured via platform metadata — this is a no-op that always resolves.
library;

export 'google_maps_loader_io.dart'
    if (dart.library.js_interop) 'google_maps_loader_web.dart';