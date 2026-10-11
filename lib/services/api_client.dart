import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base URL for the marketgo-api backend.
///
/// `--dart-define=API_URL=...` wins when set; otherwise the production API is
/// used.
String defaultApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  return 'https://api.suftrip.com';
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Supplies live auth tokens to the [ApiClient] so an expired access token can
/// be refreshed transparently and the original request retried.
///
/// The session (see AuthSession in auth_service.dart) implements this and keeps
/// the in-memory token pair in sync, and bounces the user back to sign-in when
/// a refresh is rejected (e.g. revoked token or disabled account).
class TokenSource {
  TokenSource({
    required String? Function() getAccessToken,
    required String? Function() getRefreshToken,
    required void Function({
      required String accessToken,
      required String refreshToken,
    }) store,
    required void Function() onExpired,
  })  : _getAccessToken = getAccessToken,
        _getRefreshToken = getRefreshToken,
        _store = store,
        _onExpired = onExpired;

  final String? Function() _getAccessToken;
  final String? Function() _getRefreshToken;
  final void Function({
    required String accessToken,
    required String refreshToken,
  }) _store;
  final void Function() _onExpired;

  String? get accessToken => _getAccessToken();

  String? get refreshToken => _getRefreshToken();

  void store({required String accessToken, required String refreshToken}) =>
      _store(accessToken: accessToken, refreshToken: refreshToken);

  void expire() => _onExpired();
}

class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? defaultApiBaseUrl();

  final http.Client _http;
  final String baseUrl;

  /// When set, requests carrying an `Authorization` header use the current
  /// access token and transparently refresh + retry when that token expires.
  TokenSource? tokenSource;

  static const _timeout = Duration(seconds: 15);

  /// When true the client refuses network calls so the rest of the app can
  /// fall back to local demo data (server-less test session).
  bool isOffline = false;

  /// Coalesced refresh so many concurrent 401s share one /auth/refresh call.
  Future<bool>? _refreshing;

  Future<void> _guard() async {
    if (isOffline) {
      throw const ApiException('Offline demo session', statusCode: 0);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) =>
      _request('POST', path, body: body, headers: headers);

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) =>
      _request('PUT', path, body: body, headers: headers);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) =>
      _request('PATCH', path, body: body, headers: headers);

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
  }) =>
      _request('GET', path, headers: headers);

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? headers,
  }) =>
      _request('DELETE', path, headers: headers);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    await _guard();
    final uri = Uri.parse('$baseUrl$path');
    var requestHeaders = {'Content-Type': 'application/json', ...?headers};

    // Stamp the live access token onto authenticated requests, overriding any
    // stale token the caller captured in its local variable.
    final needsAuth = headers?.containsKey('Authorization') ?? false;
    if (needsAuth) {
      final token = tokenSource?.accessToken;
      if (token == null || token.isEmpty) {
        requestHeaders = {...requestHeaders, 'Authorization': 'Bearer '};
      } else {
        requestHeaders = {...requestHeaders, 'Authorization': 'Bearer $token'};
      }
    }

    var res = await _send(method, uri, requestHeaders, body);

    if (res.statusCode == 401 && needsAuth && await _refreshTokens()) {
      final token = tokenSource?.accessToken;
      res = await _send(
          method,
          uri,
          token == null || token.isEmpty
              ? requestHeaders
              : {...requestHeaders, 'Authorization': 'Bearer $token'},
          body);
    }

    return _decode(res);
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) async {
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final streamed = await _http.send(request).timeout(_timeout);
    return http.Response.fromStream(streamed);
  }

  /// Exchanges the refresh token for a new token pair and stores it. Returns
  /// `true` when the new pair is ready, `false` otherwise. Concurrent callers
  /// share a single in-flight refresh.
  Future<bool> _refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final src = tokenSource;
    final refresh = src?.refreshToken;
    if (src == null || refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _send(
        'POST',
        Uri.parse('$baseUrl/api/v1/auth/refresh'),
        {'Content-Type': 'application/json'},
        {'refresh_token': refresh},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        src.expire();
        return false;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final access = json['access_token'] as String? ?? '';
      final refreshToken = json['refresh_token'] as String? ?? '';
      if (access.isEmpty) return false;
      src.store(accessToken: access, refreshToken: refreshToken);
      return true;
    } catch (_) {
      // Network failure: keep the session and surface the original error.
      return false;
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      json = const <String, dynamic>{};
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message =
          (json['error'] as String?) ?? 'Request failed (${res.statusCode})';
      throw ApiException(message, statusCode: res.statusCode);
    }
    return json;
  }
}
