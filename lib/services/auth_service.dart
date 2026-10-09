import 'package:flutter/foundation.dart';
import 'api_client.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  final String id;
  final String email;
  final String name;
  final String role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: '${json['id']}',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }

  String get firstName {
    final trimmed = name.trim();
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }
}

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
    );
  }
}

/// Multi-factor challenge returned by password login when MFA is enabled for
/// the account. The client must collect a one-time code and exchange it for a
/// token pair via `/api/v1/auth/mfa/verify`.
class MfaChallenge {
  const MfaChallenge({
    required this.mfaToken,
    required this.expiresIn,
    required this.channels,
    this.devCode,
  });

  final String mfaToken;
  final int expiresIn;
  final List<String> channels;

  /// When developer preview is enabled the server echoes the code itself.
  final String? devCode;

  factory MfaChallenge.fromJson(Map<String, dynamic> json) {
    return MfaChallenge(
      mfaToken: json['mfa_token'] as String? ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 300,
      channels:
          (json['channels'] as List?)?.map((e) => '$e').toList() ??
              const <String>[],
      devCode: json['dev_code'] as String?,
    );
  }
}

/// Outcome of a password login: either a ready-to-store token pair or an MFA
/// challenge the client has to resolve first.
class LoginResult {
  const LoginResult.success(this.tokens) : mfaChallenge = null;

  const LoginResult.mfaRequired(this.mfaChallenge) : tokens = null;

  final TokenPair? tokens;
  final MfaChallenge? mfaChallenge;

  bool get isMfaRequired => mfaChallenge != null;
}

/// Result of requesting an OTP code, including the delivery channels used,
/// how long the code stays valid, and (when developer preview is enabled) the
/// code itself.
class SendOtpResult {
  const SendOtpResult({
    required this.expiresIn,
    required this.channels,
    this.devCode,
  });

  final int expiresIn;
  final List<String> channels;
  final String? devCode;

  factory SendOtpResult.fromJson(Map<String, dynamic> json) {
    return SendOtpResult(
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 600,
      channels:
          (json['channels'] as List?)?.map((e) => '$e').toList() ??
              const <String>[],
      devCode: json['dev_code'] as String?,
    );
  }
}

class AuthService {
  AuthService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  /// Signs in with email + password. Returns either a token pair or — when
  /// the account has MFA enabled — the challenge to resolve next.
  Future<LoginResult> signIn(String email, String password) async {
    final data = await api.post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    if (data['mfa_required'] == true) {
      return LoginResult.mfaRequired(MfaChallenge.fromJson(data));
    }
    return LoginResult.success(TokenPair.fromJson(data));
  }

  /// Exchanges a pending MFA challenge + one-time code for a token pair.
  Future<TokenPair> verifyMfa({
    required String mfaToken,
    required String code,
  }) async {
    final data = await api.post(
      '/api/v1/auth/mfa/verify',
      body: {'mfa_token': mfaToken, 'code': code},
    );
    return TokenPair.fromJson(data);
  }

  /// Requests a one-time code delivered over WhatsApp and/or email. The phone
  /// is sent as typed; the backend normalises it to international format.
  Future<SendOtpResult> sendOtp({
    required String phone,
    String? email,
    String? name,
    String role = 'rider',
  }) async {
    final data = await api.post(
      '/api/v1/auth/otp/send',
      body: <String, dynamic>{
        'phone': phone,
        'role': role,
        if (email != null && email.isNotEmpty) 'email': email,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    return SendOtpResult.fromJson(data);
  }

  /// Exchanges the received code for a token pair, creating the account on
  /// first sign-in for the given role.
  Future<TokenPair> verifyOtp({
    required String phone,
    required String code,
    String? name,
    String role = 'rider',
  }) async {
    final data = await api.post(
      '/api/v1/auth/otp/verify',
      body: <String, dynamic>{
        'phone': phone,
        'code': code,
        'role': role,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    return TokenPair.fromJson(data);
  }

  Future<AuthUser> me(String accessToken) async {
    final data = await api.get(
      '/api/v1/auth/me',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final user = data['user'];
    if (user is Map<String, dynamic>) return AuthUser.fromJson(user);
    throw const ApiException('Unexpected profile payload');
  }

  Future<void> signOut(String accessToken, String refreshToken) async {
    await api.post(
      '/api/v1/auth/logout',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'refresh_token': refreshToken},
    );
  }
}

/// Singleton session that keeps the rider's token + profile in memory.
class AuthSession extends ChangeNotifier {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  final AuthService service = AuthService();
  AuthUser? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _loading = false;
  String? _error;
  MfaChallenge? _pendingMfa;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;

  /// Whether a sign-in or MFA verification call is currently in flight.
  bool get loading => _loading;

  /// Last sign-in / MFA error. Cleared when the next attempt starts.
  String? get error => _error;

  /// The MFA challenge awaiting a code, when password login required one.
  MfaChallenge? get pendingMfa => _pendingMfa;

  /// The shared HTTP client for this session (used by service layers).
  ApiClient get api => service.api;

  String? get accessToken => _accessToken;

  /// Stores the token pair and loads the profile, entering an authenticated
  /// session. Shared by password, MFA and phone-OTP sign-in.
  Future<void> _completeSession(TokenPair tokens) async {
    final user = await service.me(tokens.accessToken);
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _user = user;
    notifyListeners();
  }

  /// Signs in with email + password. Returns `true` when the session is open,
  /// or `false` when the server answered with an MFA challenge — in that case
  /// the challenge is kept in [pendingMfa] for the MFA screen.
  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    _pendingMfa = null;
    notifyListeners();
    try {
      final result = await service.signIn(email.trim(), password);
      if (result.isMfaRequired) {
        _pendingMfa = result.mfaChallenge;
        _loading = false;
        _error = null;
        notifyListeners();
        return false;
      }
      await _completeSession(result.tokens!);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _loading = false;
      _error = e is ApiException
          ? e.message
          : 'Could not sign in. Check your connection and try again.';
      notifyListeners();
      rethrow;
    }
  }

  /// Exchanges the code entered on the MFA screen for a token pair and
  /// completes the session. Returns `true` on success; otherwise the reason
  /// is kept in [error] for the screen to show.
  Future<bool> verifyMfaCode(String code) async {
    final challenge = _pendingMfa;
    if (challenge == null) {
      _error = 'Your verification session expired. Please sign in again.';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final tokens = await service.verifyMfa(
        mfaToken: challenge.mfaToken,
        code: code,
      );
      await _completeSession(tokens);
      _pendingMfa = null;
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _loading = false;
      _error = e is ApiException
          ? e.message
          : 'Could not verify the code. Check your connection and try again.';
      notifyListeners();
      return false;
    }
  }

  /// Discards a pending MFA challenge when the user backs out of the MFA
  /// screen without verifying.
  void cancelMfa() {
    if (_pendingMfa == null && _error == null && !_loading) return;
    _pendingMfa = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  /// Requests an OTP code for the given phone. State for the request itself
  /// lives on the OTP screen.
  Future<SendOtpResult> sendOtp(String phone, {String? email}) {
    return service.sendOtp(phone: phone, email: email, role: 'rider');
  }

  /// Completes phone sign-in: verifies the code, loads the profile and enters
  /// an authenticated session.
  Future<void> signInWithOtp(String phone, String code) async {
    final tokens = await service.verifyOtp(phone: phone, code: code);
    await _completeSession(tokens);
  }

  Future<void> logOut() async {
    final token = _accessToken;
    final refresh = _refreshToken;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _pendingMfa = null;
    _error = null;
    notifyListeners();
    if (token != null && refresh != null) {
      try {
        await service.signOut(token, refresh);
      } catch (_) {}
    }
  }
}