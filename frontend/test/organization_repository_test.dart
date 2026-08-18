import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_dashboard/features/organization/organization_models.dart';
import 'package:productivity_dashboard/repositories/organization_repository.dart';

void main() {
  test('organization repository persists project integration links offline',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = OrganizationRepository(preferences);
    const workspace =
        WorkspaceModel(id: 'workspace-test', name: 'Test workspace');

    final project = ProjectModel(
      id: 'project-test',
      workspaceId: workspace.id,
      name: 'Test project',
      linkedEventIds: const ['event-1'],
      linkedAssetIds: const ['asset-1'],
      linkedReminderIds: const ['reminder-1'],
      statusOptions: const ['planning', 'active', 'completed'],
    );

    await repository.createWorkspace(workspace);
    await repository.createProject(project);
    final loaded = (await repository.loadProjects()).single;

    expect(loaded.linkedEventIds, ['event-1']);
    expect(loaded.linkedAssetIds, ['asset-1']);
    expect(loaded.linkedReminderIds, ['reminder-1']);
    expect(loaded.statusOptions, ['planning', 'active', 'completed']);
    expect((await repository.loadQueue()).length, 2);
  });

  test('organization repository duplicates and archives projects locally',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = OrganizationRepository(preferences);
    const source = ProjectModel(
        id: 'project-source', workspaceId: 'workspace', name: 'Source');

    await repository.createProject(source);
    final copy = await repository.duplicateProject(source);
    expect(copy.name, 'Source Copy');
    expect((await repository.loadProjects()).length, 2);

    await repository.archiveProject(copy);
    expect(
        (await repository.loadProjects())
            .singleWhere((item) => item.id == copy.id)
            .archived,
        isTrue);
    await repository.deleteProject(source.id);
    expect(
        (await repository.loadProjects()).any((item) => item.id == source.id),
        isFalse);
  });
}
