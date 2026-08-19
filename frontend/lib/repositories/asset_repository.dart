import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/assets/asset_models.dart';

class AssetRepository {
  AssetRepository(this._preferences);
  final SharedPreferences _preferences;

  static const _assetsKey = 'module11_assets_v1';
  static const _foldersKey = 'module11_asset_folders_v1';
  static const _collectionsKey = 'module11_asset_collections_v1';
  static const _versionsKey = 'module11_asset_versions_v1';
  static const _queueKey = 'module11_asset_sync_queue_v1';
  static const _offlineContentLimit = 4 * 1024 * 1024;

  Future<List<AssetModel>> loadAssets() async =>
      _load(_assetsKey, AssetModel.fromJson);
  Future<List<AssetFolderModel>> loadFolders() async =>
      _load(_foldersKey, AssetFolderModel.fromJson);
  Future<List<AssetCollectionModel>> loadCollections() async =>
      _load(_collectionsKey, AssetCollectionModel.fromJson);
  Future<List<AssetVersionModel>> loadVersions() async =>
      _load(_versionsKey, AssetVersionModel.fromJson);

  Future<AssetModel?> importFile(
    PlatformFile file, {
    String workspaceId = '',
    String projectId = '',
    String folderId = 'root',
    String category = 'uncategorized',
    List<String> tags = const [],
  }) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    final hash = sha256.convert(bytes).toString();
    final current = await loadAssets();
    final duplicate =
        current.where((asset) => asset.fileHash == hash).firstOrNull;
    if (duplicate != null) return duplicate;
    final now = DateTime.now();
    final extension = _extension(file.name);
    final mimeType = _mimeTypeFor(extension);
    final retainContent = bytes.length <= _offlineContentLimit;
    final previewText = _textLike(extension, mimeType) && retainContent
        ? utf8
            .decode(bytes, allowMalformed: true)
            .substring(0, bytes.length > 200000 ? 200000 : bytes.length)
        : '';
    final asset = AssetModel(
      id: 'asset-${now.microsecondsSinceEpoch}',
      name: file.name,
      assetType: _assetType(extension, mimeType),
      sourceKind: 'file',
      extension: extension,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      fileHash: hash,
      storageKey: 'local/$hash-${file.name}',
      sourceUrl: '',
      previewText: previewText,
      ocrText: '',
      thumbnailKey: '',
      workspaceId: workspaceId,
      projectId: projectId,
      folderId: folderId,
      category: category,
      tags: List.unmodifiable(tags),
      metadata: {
        'original_name': file.name,
        'offline_limit_bytes': _offlineContentLimit
      },
      linkedTaskIds: const [],
      linkedNoteIds: const [],
      linkedEventIds: const [],
      linkedGoalIds: const [],
      linkedReminderIds: const [],
      linkedAssistantThreadIds: const [],
      favorite: false,
      pinned: false,
      archived: false,
      trashed: false,
      hidden: false,
      encrypted: false,
      locked: false,
      readingProgress: 0,
      version: 1,
      createdAt: now,
      modifiedAt: now,
      contentBase64: retainContent ? base64Encode(bytes) : '',
      offlineContent: retainContent,
    );
    await _saveAssets([...current, asset]);
    await _recordVersion(asset, 'upload');
    await _queue('asset', asset.id, 'create', asset.toJson());
    return asset;
  }

  Future<AssetModel> createUrl({
    required String name,
    required String url,
    String description = '',
    String thumbnailUrl = '',
    List<String> tags = const [],
    String category = 'url',
  }) async {
    final current = await loadAssets();
    final hash = sha256.convert(utf8.encode(url)).toString();
    final duplicate =
        current.where((asset) => asset.fileHash == hash).firstOrNull;
    if (duplicate != null) return duplicate;
    final now = DateTime.now();
    final asset = AssetModel(
      id: 'asset-${now.microsecondsSinceEpoch}',
      name: name,
      assetType: 'url',
      sourceKind: 'url',
      extension: '',
      mimeType: 'text/html',
      sizeBytes: 0,
      fileHash: hash,
      storageKey: '',
      sourceUrl: url,
      previewText: description,
      ocrText: '',
      thumbnailKey: thumbnailUrl,
      workspaceId: '',
      projectId: '',
      folderId: 'root',
      category: category,
      tags: List.unmodifiable(tags),
      metadata: {'description': description, 'thumbnail_url': thumbnailUrl},
      linkedTaskIds: const [],
      linkedNoteIds: const [],
      linkedEventIds: const [],
      linkedGoalIds: const [],
      linkedReminderIds: const [],
      linkedAssistantThreadIds: const [],
      favorite: false,
      pinned: false,
      archived: false,
      trashed: false,
      hidden: false,
      encrypted: false,
      locked: false,
      readingProgress: 0,
      version: 1,
      createdAt: now,
      modifiedAt: now,
      offlineContent: true,
    );
    await _saveAssets([...current, asset]);
    await _recordVersion(asset, 'create_url');
    await _queue('asset', asset.id, 'create', asset.toJson());
    return asset;
  }

  Future<AssetModel?> duplicateAsset(String id) async {
    final source = await findById(id);
    if (source == null) return null;
    final now = DateTime.now();
    final copy = AssetModel.fromJson({
      ...source.toJson(),
      'id': 'asset-${now.microsecondsSinceEpoch}',
      'name': '${source.name} Copy',
      'version': 1,
      'created_at': now.toIso8601String(),
      'modified_at': now.toIso8601String(),
    });
    await _saveAssets([...await loadAssets(), copy]);
    await _recordVersion(copy, 'duplicate');
    await _queue('asset', copy.id, 'duplicate',
        {'source_id': source.id, 'storage_key': source.storageKey});
    return copy;
  }

  Future<void> saveAsset(AssetModel asset, {String action = 'update'}) async {
    final assets = await loadAssets();
    await _saveAssets(
        [...assets.where((value) => value.id != asset.id), asset]);
    await _recordVersion(asset, action);
    await _queue('asset', asset.id, action, asset.toJson());
  }

  Future<void> trashAsset(String id) async {
    final asset = await findById(id);
    if (asset != null) {
      await saveAsset(asset.copyWith(trashed: true), action: 'delete');
    }
  }

  Future<void> restoreAsset(String id) async {
    final asset = await findById(id);
    if (asset != null) {
      await saveAsset(asset.copyWith(trashed: false, archived: false),
          action: 'restore');
    }
  }

  Future<void> bulkAction(
      {required List<String> ids,
      required String action,
      String? folderId,
      List<String>? tags}) async {
    for (final id in ids) {
      final asset = await findById(id);
      if (asset == null) continue;
      final next = switch (action) {
        'move' => asset.copyWith(folderId: folderId),
        'tag' => asset.copyWith(tags: tags),
        'delete' => asset.copyWith(trashed: true),
        'restore' => asset.copyWith(trashed: false, archived: false),
        'archive' => asset.copyWith(archived: true),
        'favorite' => asset.copyWith(favorite: true),
        'pin' => asset.copyWith(pinned: true),
        _ => asset,
      };
      if (next != asset) await saveAsset(next, action: 'bulk_$action');
    }
  }

  Future<AssetModel?> findById(String id) async {
    for (final asset in await loadAssets()) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  Future<List<AssetModel>> search({
    String query = '',
    String? folderId,
    String? category,
    String? assetType,
    String? tag,
    bool favoriteOnly = false,
    bool includeArchived = false,
    bool includeTrash = false,
  }) async {
    final normalized = query.trim().toLowerCase();
    return (await loadAssets()).where((asset) {
      if (!includeArchived && asset.archived) return false;
      if (!includeTrash && asset.trashed) return false;
      if (folderId != null && asset.folderId != folderId) return false;
      if (category != null && asset.category != category) return false;
      if (assetType != null && asset.assetType != assetType) return false;
      if (tag != null && !asset.tags.contains(tag)) return false;
      if (favoriteOnly && !asset.favorite) return false;
      if (normalized.isEmpty) return true;
      final haystack = [
        asset.name,
        asset.previewText,
        asset.ocrText,
        asset.category,
        ...asset.tags
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }

  Future<Uint8List?> loadContent(String id) async {
    final asset = await findById(id);
    if (asset == null || asset.contentBase64.isEmpty) return null;
    return base64Decode(asset.contentBase64);
  }

  Future<AssetFolderModel> createFolder(String name,
      {String parentId = 'root', String smartQuery = ''}) async {
    final folders = await loadFolders();
    final now = DateTime.now();
    final folder = AssetFolderModel(
        id: 'folder-${now.microsecondsSinceEpoch}',
        name: name,
        parentId: parentId,
        smartQuery: smartQuery,
        archived: false,
        createdAt: now,
        modifiedAt: now);
    await _preferences.setString(
        _foldersKey,
        jsonEncode(
            [...folders, folder].map((value) => value.toJson()).toList()));
    return folder;
  }

  Future<AssetCollectionModel> createCollection(String name,
      {String description = ''}) async {
    final collections = await loadCollections();
    final now = DateTime.now();
    final collection = AssetCollectionModel(
        id: 'collection-${now.microsecondsSinceEpoch}',
        name: name,
        description: description,
        assetIds: const [],
        passwordProtected: false,
        createdAt: now,
        modifiedAt: now);
    await _preferences.setString(
        _collectionsKey,
        jsonEncode([...collections, collection]
            .map((value) => value.toJson())
            .toList()));
    return collection;
  }

  Future<AssetStatsModel> stats() async {
    final assets = await loadAssets();
    final active = assets.where((asset) => !asset.trashed).toList();
    final categories = <String, int>{};
    for (final asset in active) {
      categories[asset.category] = (categories[asset.category] ?? 0) + 1;
    }
    final groups = <String, List<String>>{};
    for (final asset in active.where((asset) => asset.fileHash.isNotEmpty)) {
      groups.putIfAbsent(asset.fileHash, () => []).add(asset.id);
    }
    return AssetStatsModel(
        totalStorageBytes:
            active.fold(0, (sum, asset) => sum + asset.sizeBytes),
        fileCount: active.length,
        archivedCount: assets.where((asset) => asset.archived).length,
        trashedCount: assets.where((asset) => asset.trashed).length,
        favoriteCount: active.where((asset) => asset.favorite).length,
        categoryCounts: categories,
        duplicateGroups:
            groups.values.where((value) => value.length > 1).toList());
  }

  Future<String> exportMetadata() async =>
      const JsonEncoder.withIndent('  ').convert({
        'assets': (await loadAssets()).map((asset) => asset.toJson()).toList(),
        'folders':
            (await loadFolders()).map((folder) => folder.toJson()).toList(),
        'collections': (await loadCollections())
            .map((collection) => collection.toJson())
            .toList()
      });

  Future<List<Map<String, dynamic>>> loadQueue() async {
    final raw = _preferences.getString(_queueKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _recordVersion(AssetModel asset, String action) async {
    final versions = await loadVersions();
    final version = AssetVersionModel(
        id: 'version-${DateTime.now().microsecondsSinceEpoch}',
        assetId: asset.id,
        version: asset.version,
        action: action,
        name: asset.name,
        fileHash: asset.fileHash,
        sizeBytes: asset.sizeBytes,
        createdAt: DateTime.now());
    await _preferences.setString(
        _versionsKey,
        jsonEncode(
            [...versions, version].map((value) => value.toJson()).toList()));
  }

  Future<void> _queue(String entityType, String entityId, String operation,
      Map<String, dynamic> payload) async {
    final queue = [...await loadQueue()];
    queue.add({
      'id':
          '$entityType:$entityId:$operation:${DateTime.now().microsecondsSinceEpoch}',
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String()
    });
    await _preferences.setString(_queueKey, jsonEncode(queue));
  }

  Future<void> _saveAssets(List<AssetModel> assets) async =>
      _preferences.setString(_assetsKey,
          jsonEncode(assets.map((asset) => asset.toJson()).toList()));

  Future<List<T>> _load<T>(
      String key, T Function(Map<String, dynamic>) fromJson) async {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    } on Object {
      return const [];
    }
  }

  String _extension(String name) =>
      name.contains('.') ? '.${name.split('.').last.toLowerCase()}' : '';

  String _mimeTypeFor(String extension) => switch (extension) {
        '.pdf' => 'application/pdf',
        '.md' || '.markdown' => 'text/markdown',
        '.txt' || '.log' => 'text/plain',
        '.json' => 'application/json',
        '.csv' => 'text/csv',
        '.png' => 'image/png',
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.gif' => 'image/gif',
        '.webp' => 'image/webp',
        '.mp3' => 'audio/mpeg',
        '.wav' => 'audio/wav',
        '.mp4' => 'video/mp4',
        _ => 'application/octet-stream',
      };

  bool _textLike(String extension, String mimeType) =>
      mimeType.startsWith('text/') ||
      const {
        '.txt',
        '.md',
        '.markdown',
        '.json',
        '.csv',
        '.dart',
        '.py',
        '.js',
        '.ts',
        '.html',
        '.css',
        '.sql',
        '.yaml',
        '.yml'
      }.contains(extension);
  String _assetType(String extension, String mimeType) {
    if (mimeType.startsWith('image/') ||
        const {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg'}
            .contains(extension)) {
      return 'image';
    }
    if (mimeType.startsWith('audio/')) {
      return 'audio';
    }
    if (mimeType.startsWith('video/')) {
      return 'video';
    }
    if (extension == '.pdf' || mimeType == 'application/pdf') {
      return 'pdf';
    }
    if (_textLike(extension, mimeType)) {
      return const {'.dart', '.py', '.js', '.ts', '.html', '.css', '.sql'}
              .contains(extension)
          ? 'code'
          : 'text';
    }
    return 'document';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
