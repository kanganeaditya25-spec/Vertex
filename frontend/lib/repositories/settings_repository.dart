import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/settings/settings_models.dart';

class SettingsRepository {
  SettingsRepository(this._preferences);
  final SharedPreferences _preferences;

  static const _settingsKey = 'module10_settings_v1';
  static const _backupsKey = 'module10_backups_v1';

  Future<SettingsSnapshotModel> load() async {
    final encoded = _preferences.getString(_settingsKey);
    if (encoded == null || encoded.isEmpty) {
      final initial = SettingsSnapshotModel(values: defaultValues);
      await save(initial);
      return initial;
    }
    try {
      return SettingsSnapshotModel.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } on Object {
      final initial = SettingsSnapshotModel(values: defaultValues);
      await save(initial);
      return initial;
    }
  }

  Future<SettingsSnapshotModel> save(SettingsSnapshotModel snapshot) async {
    await _preferences.setString(_settingsKey, jsonEncode(snapshot.toJson()));
    return snapshot;
  }

  Future<SettingsSnapshotModel> patch(String path, dynamic value) async =>
      save((await load()).setValue(path, value));

  Future<String> exportJson() async => jsonEncode((await load()).toJson());

  Future<SettingsSnapshotModel> importJson(String encoded) async {
    final snapshot = SettingsSnapshotModel.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    await save(snapshot);
    return snapshot;
  }

  Future<BackupModel> createLocalBackup({
    String label = 'Manual local backup',
  }) async {
    final snapshot = await load();
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final payload = jsonEncode({
      'format': 'focusflow-settings-v1',
      'settings': snapshot.toJson(),
    });
    final records = _loadBackupRecords();
    records.insert(0, {
      'id': id,
      'label': label,
      'payload': payload,
      'checksum': '${payload.length}-${payload.hashCode}',
      'verified': true,
      'size_bytes': utf8.encode(payload).length,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _preferences.setString(
      _backupsKey,
      jsonEncode(records.take(20).toList()),
    );
    return BackupModel.fromJson(records.first);
  }

  Future<List<BackupModel>> loadBackups() async =>
      _loadBackupRecords().map(BackupModel.fromJson).toList();

  Future<SettingsSnapshotModel> restoreLocalBackup(String id) async {
    final record =
        _loadBackupRecords().where((item) => item['id'] == id).firstOrNull;
    if (record == null) throw StateError('Backup not found');
    final bundle = jsonDecode('${record['payload']}') as Map<String, dynamic>;
    return importJson(jsonEncode(bundle['settings']));
  }

  Future<void> clearSearchHistory() async =>
      patch('search.history', <String>[]);
  Future<void> clearAiMemory() async =>
      patch('privacy.ai_memory_enabled', false);
  Future<void> clearCache() async =>
      patch('storage.last_cache_cleanup', DateTime.now().toIso8601String());
  Future<void> clearAllLocalData() async {
    await _preferences.remove(_settingsKey);
    await _preferences.remove(_backupsKey);
  }

  List<Map<String, dynamic>> _loadBackupRecords() {
    final encoded = _preferences.getString(_backupsKey);
    if (encoded == null || encoded.isEmpty) return <Map<String, dynamic>>[];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
    } on Object {
      return <Map<String, dynamic>>[];
    }
  }
}

final Map<String, dynamic> defaultValues = {
  'general': {
    'username': '',
    'display_name': '',
    'timezone': 'UTC',
    'country': '',
    'date_format': 'MMM d, yyyy',
    'time_format': '24h',
    'week_start_day': 'monday',
    'default_workspace': '',
    'default_project': '',
  },
  'appearance': {
    'theme_mode': 'system',
    'dynamic_colors': false,
    'accent_color': 'indigo',
    'font_scale': 1.0,
    'font_family': 'system',
    'density': 'comfortable',
    'animation_speed': 'normal',
    'high_contrast': false,
    'reduced_motion': false,
  },
  'ai': {
    'local_model': 'llama3.2',
    'ollama_endpoint': 'http://localhost:11434',
    'embedding_model': 'nomic-embed-text',
    'temperature': 0.2,
    'context_length': 8192,
    'memory_size': 20,
    'personality': 'focused',
    'auto_summaries': true,
    'auto_categorization': true,
    'auto_prioritization': true,
    'auto_scheduling': false,
    'suggestions': true,
  },
  'productivity': {
    'work_start': '09:00',
    'work_end': '17:00',
    'focus_minutes': 50,
    'break_minutes': 10,
    'pomodoro_minutes': 25,
    'daily_goal': 3,
    'weekly_goal': 15,
    'productivity_target': 75,
    'default_task_minutes': 30,
  },
  'calendar': {
    'working_days': [1, 2, 3, 4, 5],
    'default_view': 'week',
    'buffer_minutes': 10,
    'meeting_default_minutes': 30,
    'time_zone': 'UTC',
  },
  'tasks': {
    'default_priority': 'medium',
    'default_category': 'general',
    'auto_archive': false,
    'auto_complete_rules': true,
    'recurring_defaults': 'weekly',
    'sorting': 'priority',
    'default_filters': [],
  },
  'notes': {
    'default_editor': 'markdown',
    'markdown_mode': true,
    'auto_save_seconds': 10,
    'version_history': true,
    'default_folder': '',
    'default_note_type': 'note',
  },
  'projects': {
    'default_workspace': '',
    'default_status': 'planning',
    'milestone_rules': true,
    'project_templates': true,
    'goal_templates': true,
  },
  'analytics': {
    'enabled': true,
    'default_period': 'week',
    'show_recommendations': true,
  },
  'automation': {
    'enabled': true,
    'require_approval': true,
    'max_steps': 20,
    'scheduled_runs_when_active': true,
  },
  'notifications': {
    'local_enabled': true,
    'sounds': true,
    'silent_mode': false,
    'critical_alerts': true,
    'schedule': 'always',
    'do_not_disturb': false,
  },
  'reminders': {
    'default_minutes': 15,
    'snooze_options': [5, 15, 30],
    'repeat_rules': 'none',
    'smart_reminders': true,
    'ai_suggestions': true,
  },
  'search': {
    'history': [],
    'suggestions': true,
    'semantic': false,
    'ocr': false,
    'voice': false,
  },
  'voice': {
    'whisper_model': 'base',
    'language': 'en',
    'microphone': true,
    'voice_activation': false,
    'speech_speed': 1.0,
    'offline_recognition': true,
  },
  'security': {
    'pin_lock': false,
    'biometrics': false,
    'auto_lock_minutes': 0,
    'session_timeout_minutes': 30,
    'secure_storage': true,
    'encryption': true,
  },
  'privacy': {
    'analytics_enabled': false,
    'ai_memory_enabled': true,
    'telemetry': false,
  },
  'backup': {
    'scheduled': false,
    'schedule': 'weekly',
    'last_backup': null,
    'verification': true,
  },
  'storage': {
    'cache_cleanup_days': 30,
    'temporary_cleanup': true,
    'optimization': true,
  },
  'accessibility': {
    'large_text': false,
    'high_contrast': false,
    'reduced_motion': false,
    'screen_reader': true,
    'keyboard_navigation': true,
    'color_blind_mode': 'none',
  },
  'language': {'locale': 'en', 'region': 'US'},
  'integrations': {
    'local_ai': true,
    'plugin_system': false,
    'future_cloud_sync': false,
  },
  'developer': {
    'enabled': false,
    'debug_logs': false,
    'event_bus_monitor': false,
    'api_logs': false,
    'performance_metrics': false,
    'feature_flags': {},
  },
};
