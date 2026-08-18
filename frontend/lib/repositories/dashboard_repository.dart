import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._preferences);

  final SharedPreferences _preferences;
  static const _snapshotKey = 'dashboard_snapshot_v1';
  static const _preferencesKey = 'dashboard_preferences_v1';

  Future<DashboardSnapshot> loadSnapshot() async {
    final encoded = _preferences.getString(_snapshotKey);
    if (encoded == null || encoded.isEmpty) return DashboardSnapshot.empty();

    try {
      return DashboardSnapshot.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } on Object {
      return DashboardSnapshot.empty();
    }
  }

  Future<void> saveSnapshot(DashboardSnapshot snapshot) async {
    await _preferences.setString(_snapshotKey, jsonEncode(snapshot.toJson()));
  }

  DashboardPreferences loadPreferences() {
    final encoded = _preferences.getString(_preferencesKey);
    if (encoded == null || encoded.isEmpty) return DashboardPreferences.defaults();

    try {
      return DashboardPreferences.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } on Object {
      return DashboardPreferences.defaults();
    }
  }

  Future<void> savePreferences(DashboardPreferences preferences) async {
    await _preferences.setString(_preferencesKey, jsonEncode(preferences.toJson()));
  }
}
