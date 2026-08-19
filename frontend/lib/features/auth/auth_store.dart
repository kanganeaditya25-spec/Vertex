import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  Future<AuthSession?> build() async {
    _preferences = await SharedPreferences.getInstance();
    final raw = _preferences!.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> signUp(
      {required String name,
      required String email,
      required String password}) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    _validate(normalizedName, normalizedEmail, password, requireName: true);
    final preferences = await _ready();
    if (preferences.containsKey(_accountKey)) {
      final existing = _readAccount(preferences);
      if (existing['email'] == normalizedEmail) {
        throw const AuthException(
            'An account with this email already exists. Sign in instead.');
      }
    }
    await preferences.setString(
      _accountKey,
      jsonEncode({
        'name': normalizedName,
        'email': normalizedEmail,
        'passwordHash': _hash(password),
      }),
    );
    await _setSession(
        AuthSession(name: normalizedName, email: normalizedEmail));
  }

  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    _validate('', normalizedEmail, password);
    final preferences = await _ready();
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
    state = const AsyncData(null);
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
