import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 认证状态枚举
enum AuthStatus { authenticated, unauthenticated, authenticating, refreshing }

/// 认证令牌模型
class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  AuthTokens({required this.accessToken, this.refreshToken, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));
  bool get willExpireSoon => DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final expiresIn = json['expires_in'] as int? ?? 3600;
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }
}

/// 认证服务 — JWT 令牌管理
/// 职责:
/// - login(username, password) → 获取 JWT
/// - refreshToken() → 刷新 access_token
/// - getValidAccessToken() → 获取有效令牌 (自动刷新)
/// - logout() → 清除令牌
/// - 持久化到 SharedPreferences
class AuthService {
  final String baseUrl;
  final http.Client _client;

  AuthTokens? _tokens;
  AuthStatus _status = AuthStatus.unauthenticated;
  final _statusController = StreamController<AuthStatus>.broadcast();

  AuthService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  AuthStatus get status => _status;
  Stream<AuthStatus> get statusStream => _statusController.stream;
  AuthTokens? get tokens => _tokens;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// 初始化: 从 SharedPreferences 加载持久化令牌
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenJson = prefs.getString('auth_tokens');
    if (tokenJson != null) {
      try {
        _tokens = AuthTokens.fromJson(jsonDecode(tokenJson));
        if (!_tokens!.isExpired) {
          _setStatus(AuthStatus.authenticated);
        } else if (_tokens!.refreshToken != null) {
          await refreshToken();
        } else {
          _setStatus(AuthStatus.unauthenticated);
        }
      } catch (_) {
        _setStatus(AuthStatus.unauthenticated);
      }
    }
  }

  /// 登录
  Future<bool> login(String username, String password) async {
    _setStatus(AuthStatus.authenticating);
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _tokens = AuthTokens.fromJson(jsonDecode(response.body));
        await _persistTokens();
        _setStatus(AuthStatus.authenticated);
        return true;
      }
      _setStatus(AuthStatus.unauthenticated);
      return false;
    } catch (_) {
      _setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  /// 刷新令牌
  Future<bool> refreshToken() async {
    if (_tokens?.refreshToken == null) return false;
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_tokens!.refreshToken}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _tokens = AuthTokens.fromJson(jsonDecode(response.body));
        await _persistTokens();
        _setStatus(AuthStatus.authenticated);
        return true;
      }
      await logout();
      return false;
    } catch (_) {
      _setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  /// 获取有效 access token (自动刷新)
  Future<String?> getValidAccessToken() async {
    if (_tokens == null) return null;
    if (_tokens!.willExpireSoon && _tokens!.refreshToken != null) {
      await refreshToken();
    }
    if (_tokens != null && !_tokens!.isExpired) {
      return _tokens!.accessToken;
    }
    return null;
  }

  /// 登出
  Future<void> logout() async {
    _tokens = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_tokens');
    _setStatus(AuthStatus.unauthenticated);
  }

  void _setStatus(AuthStatus s) {
    _status = s;
    _statusController.add(s);
  }

  Future<void> _persistTokens() async {
    if (_tokens == null) return;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('auth_tokens', jsonEncode({
      'access_token': _tokens!.accessToken,
      'refresh_token': _tokens!.refreshToken,
      'expires_in': _tokens!.expiresAt.difference(DateTime.now()).inSeconds,
    }));
  }

  void dispose() {
    _statusController.close();
    _client.close();
  }
}
