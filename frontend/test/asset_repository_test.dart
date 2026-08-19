import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_dashboard/repositories/asset_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('imports files offline, skips duplicate hashes, and persists content',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = AssetRepository(preferences);
    final bytes = Uint8List.fromList('# Local note\nAsset Library'.codeUnits);
    final file =
        PlatformFile(name: 'note.md', size: bytes.length, bytes: bytes);

    final first = await repository.importFile(file, tags: ['knowledge']);
    final duplicate = await repository.importFile(file);

    expect(first, isNotNull);
    expect(duplicate?.id, first?.id);
    expect(first?.offlineContent, isTrue);
    expect(String.fromCharCodes((await repository.loadContent(first!.id))!),
        contains('Local note'));
    expect((await repository.loadAssets()), hasLength(1));
    expect((await repository.loadQueue()), hasLength(1));
    expect((await repository.loadVersions()), hasLength(1));
  });

  test('saves URL resources and searches by metadata', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = AssetRepository(preferences);
    final url = 'https://example.com/focusflow';

    final first = await repository.createUrl(
        name: 'FocusFlow documentation',
        url: url,
        description: 'Productivity knowledge resource',
        tags: ['docs']);
    final duplicate = await repository.createUrl(name: 'Duplicate', url: url);
    final results = await repository.search(query: 'knowledge');

    expect(duplicate.id, first.id);
    expect(results.map((asset) => asset.id), contains(first.id));
    expect((await repository.stats()).fileCount, 1);
  });

  test('supports folders and lifecycle actions through the local queue',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = AssetRepository(preferences);
    final folder = await repository.createFolder('Research');
    final bytes = Uint8List.fromList('research'.codeUnits);
    final asset = await repository.importFile(
        PlatformFile(name: 'research.txt', size: bytes.length, bytes: bytes));

    await repository.saveAsset(asset!.copyWith(folderId: folder.id),
        action: 'move');
    await repository.trashAsset(asset.id);
    expect((await repository.search()).isEmpty, isTrue);
    await repository.restoreAsset(asset.id);
    expect((await repository.search()).single.folderId, folder.id);
    expect((await repository.loadQueue()).length, greaterThanOrEqualTo(3));
  });
}
