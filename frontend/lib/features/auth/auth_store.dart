import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';

final authStoreProvider =
    AsyncNotifierProvider<AuthStore, AuthSession?>(AuthStore.new);

class AuthSession {
  const AuthSession(
      {required this.name, this.email = '', this.isGuest = false});

  final String name;
  final String email;
  final bool isGuest;

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'isGuest': isGuest,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        name: json['name'] as String? ?? 'there',
        email: json['email'] as String? ?? '',
        isGuest: json['isGuest'] as bool? ?? false,
      );
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthStore extends AsyncNotifier<AuthSession?> {
  static const _accountKey = 'focusflow_local_account';
  static const _sessionKey = 'focusflow_auth_session';
  SharedPreferences? _preferences;
  final Dio _client = Dio();

  @override
  Future<AuthSession?> build() async {
    _preferences = await SharedPreferences.getInstance();
    final raw = _preferences!.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    _validate(normalizedName, normalizedEmail, password, requireName: true);
    final preferences = await _ready();

    final apiSession = await _tryApiSession('/auth/signup', {
      'name': normalizedName,
      'email': normalizedEmail,
      'password': password,
    });
    if (apiSession != null) {
      await _saveLocalAccount(
          preferences, normalizedName, normalizedEmail, password);
      await _setSession(apiSession);
      return;
    }

    if (preferences.containsKey(_accountKey)) {
      final existing = _readAccount(preferences);
      if (existing['email'] == normalizedEmail) {
        throw const AuthException(
            'An account with this email already exists. Sign in instead.');
      }
    }
    await _saveLocalAccount(
        preferences, normalizedName, normalizedEmail, password);
    await _setSession(
        AuthSession(name: normalizedName, email: normalizedEmail));
  }

  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    _validate('', normalizedEmail, password);
    final preferences = await _ready();

    final apiSession = await _tryApiSession('/auth/email-login', {
      'email': normalizedEmail,
      'password': password,
    });
    if (apiSession != null) {
      await _saveLocalAccount(
          preferences, apiSession.name, normalizedEmail, password);
      await _setSession(apiSession);
      return;
    }

    if (!preferences.containsKey(_accountKey)) {
      throw const AuthException(
          'No local account exists yet. Create one to get started.');
    }
    final account = _readAccount(preferences);
    if (account['email'] != normalizedEmail ||
        account['passwordHash'] != _hash(password)) {
      throw const AuthException('Email or password is incorrect.');
    }
    await _setSession(AuthSession(
        name: account['name'] as String? ?? 'there', email: normalizedEmail));
  }

  Future<void> continueOffline() async =>
      _setSession(const AuthSession(name: 'there', isGuest: true));

  Future<void> signOut() async {
    final preferences = await _ready();
    await preferences.remove(_sessionKey);
    await preferences.remove(AppConfig.authTokenKey);
    state = const AsyncData(null);
  }

  Future<AuthSession?> _tryApiSession(
      String path, Map<String, dynamic> payload) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '${AppConfig.apiBaseUrl}$path',
        data: payload,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final data = response.data;
      final token = data?['token'] as String?;
      if (token == null || token.isEmpty) return null;
      final preferences = await _ready();
      await preferences.setString(AppConfig.authTokenKey, token);
      return AuthSession(
        name: data?['name'] as String? ?? 'there',
        email: data?['email'] as String? ?? '',
      );
    } on DioException {
      return null;
    }
  }

  Future<void> _saveLocalAccount(
    SharedPreferences preferences,
    String name,
    String email,
    String password,
  ) async {
    await preferences.setString(
      _accountKey,
      jsonEncode({
        'name': name,
        'email': email,
        'passwordHash': _hash(password),
      }),
    );
  }

  Future<SharedPreferences> _ready() async {
    _preferences ??= await SharedPreferences.getInstance();
    return _preferences!;
  }

  Map<String, dynamic> _readAccount(SharedPreferences preferences) {
    final raw = preferences.getString(_accountKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _setSession(AuthSession session) async {
    final preferences = await _ready();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
    state = AsyncData(session);
  }

  void _validate(String name, String email, String password,
      {bool requireName = false}) {
    if (requireName && name.length < 2) {
      throw const AuthException(
          'Enter your name so FocusFlow can personalize the workspace.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.length < 8) {
      throw const AuthException('Use a password with at least 8 characters.');
    }
  }

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
}
