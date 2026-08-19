import 'dart:convert';

class SettingsSnapshotModel {
  const SettingsSnapshotModel({
    required this.values,
    this.favorites = const [],
    this.recentChanges = const [],
    this.version = 1,
    this.updatedAt,
  });
  final Map<String, dynamic> values;
  final List<String> favorites;
  final List<String> recentChanges;
  final int version;
  final DateTime? updatedAt;

  dynamic valueAt(String path, [dynamic fallback]) {
    dynamic current = values;
    for (final part in path.split('.')) {
      if (current is! Map<String, dynamic> || !current.containsKey(part)) {
        return fallback;
      }
      current = current[part];
    }
    return current ?? fallback;
  }

  SettingsSnapshotModel setValue(String path, dynamic value) {
    final next = jsonDecode(jsonEncode(values)) as Map<String, dynamic>;
    final parts = path.split('.');
    var cursor = next;
    for (final part in parts.take(parts.length - 1)) {
      final child = cursor[part];
      if (child is Map<String, dynamic>) {
        cursor = child;
      } else {
        cursor[part] = <String, dynamic>{};
        cursor = cursor[part] as Map<String, dynamic>;
      }
    }
    cursor[parts.last] = value;
    return SettingsSnapshotModel(
      values: next,
      favorites: favorites,
      recentChanges: [
        path,
        ...recentChanges.where((item) => item != path),
      ].take(30).toList(),
      version: version + 1,
      updatedAt: DateTime.now(),
    );
  }

  SettingsSnapshotModel copyWith({
    Map<String, dynamic>? values,
    List<String>? favorites,
    List<String>? recentChanges,
    int? version,
    DateTime? updatedAt,
  }) =>
      SettingsSnapshotModel(
        values: values ?? this.values,
        favorites: favorites ?? this.favorites,
        recentChanges: recentChanges ?? this.recentChanges,
        version: version ?? this.version,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory SettingsSnapshotModel.fromJson(Map<String, dynamic> json) =>
      SettingsSnapshotModel(
        values: _map(json['values']),
        favorites: _strings(json['favorites']),
        recentChanges: _strings(
          json['recent_changes'] ?? json['recentChanges'],
        ),
        version: (json['version'] as num?)?.toInt() ?? 1,
        updatedAt: _date(json['updated_at'] ?? json['updatedAt']),
      );
  Map<String, dynamic> toJson() => {
        'values': values,
        'favorites': favorites,
        'recent_changes': recentChanges,
        'version': version,
        'updated_at': updatedAt?.toIso8601String(),
      };
}

class SettingsCategoryModel {
  const SettingsCategoryModel({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    required this.fields,
  });
  final String id;
  final String label;
  final String icon;
  final String description;
  final List<SettingsFieldModel> fields;
}

class SettingsFieldModel {
  const SettingsFieldModel({
    required this.path,
    required this.label,
    required this.description,
    this.type = 'text',
    this.options = const [],
  });
  final String path;
  final String label;
  final String description;
  final String type;
  final List<String> options;
}

class SettingsSearchResultModel {
  const SettingsSearchResultModel({
    required this.path,
    required this.category,
    required this.label,
  });
  final String path;
  final String category;
  final String label;
  factory SettingsSearchResultModel.fromJson(Map<String, dynamic> json) =>
      SettingsSearchResultModel(
        path: '${json['path'] ?? ''}',
        category: '${json['category'] ?? ''}',
        label: '${json['label'] ?? ''}',
      );
}

class BackupModel {
  const BackupModel({
    required this.id,
    required this.label,
    required this.checksum,
    required this.verified,
    required this.sizeBytes,
    required this.createdAt,
  });
  final String id;
  final String label;
  final String checksum;
  final bool verified;
  final int sizeBytes;
  final DateTime? createdAt;
  factory BackupModel.fromJson(Map<String, dynamic> json) => BackupModel(
        id: '${json['id'] ?? ''}',
        label: '${json['label'] ?? ''}',
        checksum: '${json['checksum'] ?? ''}',
        verified: json['verified'] as bool? ?? false,
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        createdAt: _date(json['created_at'] ?? json['createdAt']),
      );
}

class StorageStatsModel {
  const StorageStatsModel({
    this.settingsBytes = 0,
    this.backupBytes = 0,
    this.databaseBytes = 0,
    this.cacheBytes = 0,
    this.modelBytes = 0,
    this.freeSpaceBytes,
  });
  final int settingsBytes;
  final int backupBytes;
  final int databaseBytes;
  final int cacheBytes;
  final int modelBytes;
  final int? freeSpaceBytes;
  factory StorageStatsModel.fromJson(Map<String, dynamic> json) =>
      StorageStatsModel(
        settingsBytes: (json['settings_bytes'] as num?)?.toInt() ?? 0,
        backupBytes: (json['backup_bytes'] as num?)?.toInt() ?? 0,
        databaseBytes: (json['database_bytes'] as num?)?.toInt() ?? 0,
        cacheBytes: (json['cache_bytes'] as num?)?.toInt() ?? 0,
        modelBytes: (json['model_bytes'] as num?)?.toInt() ?? 0,
        freeSpaceBytes: (json['free_space_bytes'] as num?)?.toInt(),
      );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : <String>[];
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
