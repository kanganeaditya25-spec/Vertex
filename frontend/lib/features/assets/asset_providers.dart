import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/asset_repository.dart';
import 'asset_models.dart';

final assetControllerProvider =
    AsyncNotifierProvider<AssetController, AssetState>(AssetController.new);

class AssetState {
  const AssetState(
      {required this.assets,
      required this.folders,
      required this.collections,
      required this.stats,
      this.query = '',
      this.selectedFolder = 'root',
      this.selectedType = 'all',
      this.viewMode = 'grid',
      this.selectedIds = const []});
  final List<AssetModel> assets;
  final List<AssetFolderModel> folders;
  final List<AssetCollectionModel> collections;
  final AssetStatsModel stats;
  final String query;
  final String selectedFolder;
  final String selectedType;
  final String viewMode;
  final List<String> selectedIds;

  List<AssetModel> get visibleAssets => assets.where((asset) {
        if (selectedFolder == 'trash' && !asset.trashed) {
          return false;
        }
        if (selectedFolder == 'archive' && (!asset.archived || asset.trashed)) {
          return false;
        }
        if (selectedFolder == 'favorite' &&
            (!asset.favorite || asset.trashed)) {
          return false;
        }
        if (selectedFolder == 'recent' &&
            (asset.trashed ||
                DateTime.now().difference(asset.modifiedAt).inDays > 30)) {
          return false;
        }
        if (selectedFolder == 'all' && (asset.trashed || asset.archived)) {
          return false;
        }
        if (!{'all', 'trash', 'archive', 'favorite', 'recent'}
                .contains(selectedFolder) &&
            asset.folderId != selectedFolder) {
          return false;
        }
        if (selectedType != 'all' && asset.assetType != selectedType) {
          return false;
        }
        if (query.trim().isEmpty) return true;
        final text = [
          asset.name,
          asset.category,
          asset.previewText,
          asset.ocrText,
          ...asset.tags
        ].join(' ').toLowerCase();
        return text.contains(query.trim().toLowerCase());
      }).toList();

  AssetState copyWith(
          {List<AssetModel>? assets,
          List<AssetFolderModel>? folders,
          List<AssetCollectionModel>? collections,
          AssetStatsModel? stats,
          String? query,
          String? selectedFolder,
          String? selectedType,
          String? viewMode,
          List<String>? selectedIds}) =>
      AssetState(
          assets: assets ?? this.assets,
          folders: folders ?? this.folders,
          collections: collections ?? this.collections,
          stats: stats ?? this.stats,
          query: query ?? this.query,
          selectedFolder: selectedFolder ?? this.selectedFolder,
          selectedType: selectedType ?? this.selectedType,
          viewMode: viewMode ?? this.viewMode,
          selectedIds: selectedIds ?? this.selectedIds);
}

class AssetController extends AsyncNotifier<AssetState> {
  AssetRepository? _repository;

  @override
  Future<AssetState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = AssetRepository(preferences);
    return _loadState();
  }

  Future<AssetState> _loadState({AssetState? current}) async {
    final assets = await _repository!.loadAssets();
    return (current ??
            const AssetState(
                assets: [],
                folders: [],
                collections: [],
                stats: AssetStatsModel()))
        .copyWith(
            assets: assets,
            folders: await _repository!.loadFolders(),
            collections: await _repository!.loadCollections(),
            stats: await _repository!.stats());
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    state = AsyncData(await _loadState(current: current));
  }

  Future<int> importFiles(FilePickerResult result) async {
    if (_repository == null) return 0;
    var imported = 0;
    for (final file in result.files) {
      final asset = await _repository!.importFile(file);
      if (asset != null) imported++;
    }
    await refresh();
    return imported;
  }

  Future<AssetModel?> createUrl(
      {required String name,
      required String url,
      String description = '',
      List<String> tags = const []}) async {
    if (_repository == null) return null;
    final asset = await _repository!
        .createUrl(name: name, url: url, description: description, tags: tags);
    await refresh();
    return asset;
  }

  Future<void> duplicateAsset(String id) async {
    await _repository?.duplicateAsset(id);
    await refresh();
  }

  Future<void> saveAsset(AssetModel asset, {String action = 'update'}) async {
    await _repository?.saveAsset(asset, action: action);
    await refresh();
  }

  Future<void> bulkActionFor(List<String> ids, String action) async {
    if (_repository == null) return;
    await _repository!.bulkAction(ids: ids, action: action);
    await refresh();
  }

  Future<void> bulkAction(String action) async {
    final current = state.valueOrNull;
    if (_repository == null || current == null || current.selectedIds.isEmpty) {
      return;
    }
    await _repository!.bulkAction(
        ids: current.selectedIds,
        action: action,
        folderId:
            current.selectedFolder == 'root' ? null : current.selectedFolder);
    state = AsyncData(
        (await _loadState(current: current)).copyWith(selectedIds: const []));
  }

  Future<void> createFolder(String name) async {
    await _repository?.createFolder(name);
    await refresh();
  }

  Future<void> createCollection(String name, String description) async {
    await _repository?.createCollection(name, description: description);
    await refresh();
  }

  void setQuery(String query) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(query: query));
  }

  void setFolder(String folderId) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
          current.copyWith(selectedFolder: folderId, selectedIds: const []));
    }
  }

  void setType(String type) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(selectedType: type));
    }
  }

  void setViewMode(String mode) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(viewMode: mode));
  }

  void toggleSelection(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    final selected = current.selectedIds.contains(id)
        ? current.selectedIds.where((value) => value != id).toList()
        : [...current.selectedIds, id];
    state = AsyncData(current.copyWith(selectedIds: selected));
  }

  void clearSelection() {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(selectedIds: const []));
    }
  }
}
