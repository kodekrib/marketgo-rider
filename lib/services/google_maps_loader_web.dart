import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

const _scriptId = 'marketgo-google-maps-js';

Future<void>? _pending;
bool _done = false;

/// Injects the Maps JS bootstrap script for [apiKey] and resolves once it has
/// loaded (or errored). Callers that build a `GoogleMap` must await this first
/// so the global `google.maps` API exists. Repeated calls share the load.
Future<void> ensureGoogleMaps(String apiKey) {
  if (!kIsWeb) return Future<void>.value();
  final key = apiKey.trim();
  if (key.isEmpty) return Future<void>.value();
  if (_done) return Future<void>.value();
  return _pending ??= _injectAndWait(key);
}

Future<void> _injectAndWait(String key) async {
  if (web.document.getElementById(_scriptId) == null) {
    final completer = Completer<void>();
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    script.id = _scriptId;
    script.src =
        'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(key)}&v=weekly';
    script.async = true;
    script.defer = true;
    script.onload = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;
    script.onerror = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;
    web.document.head!.append(script);
    await completer.future.timeout(const Duration(seconds: 20),
        onTimeout: () {});
  }
  _done = true;
}