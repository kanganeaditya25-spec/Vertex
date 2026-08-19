import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_dashboard/repositories/graph_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists graph nodes, relationships, degrees, and paths offline',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = GraphRepository(preferences);
    final project = await repository.upsertNode(
      entityType: 'project',
      entityId: 'project-1',
      workspaceId: 'workspace-1',
      label: 'Focus project',
      contentText: 'deep work planning',
      tags: const ['focus'],
    );
    final task = await repository.upsertNode(
      entityType: 'task',
      entityId: 'task-1',
      workspaceId: 'workspace-1',
      label: 'Planning task',
      contentText: 'deep work planning',
      tags: const ['focus'],
    );

    final relationship = await repository.ensureRelationship(
      workspaceId: 'workspace-1',
      sourceNodeId: task.id,
      targetNodeId: project.id,
      relationshipType: 'belongs to',
    );
    final path =
        await repository.path(task.id, project.id, workspaceId: 'workspace-1');
    final stats = await repository.stats(workspaceId: 'workspace-1');

    expect(relationship, isNotNull);
    expect(path.found, isTrue);
    expect(stats.totalNodes, 2);
    expect(stats.totalRelationships, 1);
    expect(
        (await repository.loadNodes())
            .firstWhere((node) => node.id == task.id)
            .degree,
        1);
  });

  test(
      'generates explainable suggestions, accepts them, and detects duplicates',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = GraphRepository(preferences);
    await repository.upsertNode(
      entityType: 'note',
      entityId: 'note-1',
      workspaceId: 'workspace-1',
      label: 'Focus note',
      contentText: 'protect a deep work block every morning',
      tags: const ['focus', 'morning'],
    );
    await repository.upsertNode(
      entityType: 'asset',
      entityId: 'asset-1',
      workspaceId: 'workspace-1',
      label: 'Focus resource',
      contentText: 'protect a deep work block every morning',
      tags: const ['focus', 'morning'],
    );

    final suggestions =
        await repository.suggestions(workspaceId: 'workspace-1');
    final duplicates = await repository.duplicates(workspaceId: 'workspace-1');
    final relationship = await repository.acceptSuggestion(suggestions.first);
    final stats = await repository.stats(workspaceId: 'workspace-1');

    expect(suggestions, isNotEmpty);
    expect(suggestions.first.explanation, contains('Suggested because'));
    expect(duplicates, isNotEmpty);
    expect(relationship?.source, 'ai_suggestion');
    expect(stats.acceptedSuggestions, 1);
  });

  test('keeps workspaces isolated', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = GraphRepository(preferences);
    await repository.upsertNode(
        entityType: 'note', entityId: 'one', workspaceId: 'one', label: 'One');
    await repository.upsertNode(
        entityType: 'note', entityId: 'two', workspaceId: 'two', label: 'Two');

    final one = await repository.search('One', workspaceId: 'one');
    final two = await repository.search('One', workspaceId: 'two');

    expect(one.map((node) => node.entityId), contains('one'));
    expect(two, isEmpty);
  });
}
