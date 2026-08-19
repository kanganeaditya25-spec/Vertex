import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity_dashboard/features/organization/organization_models.dart';
import 'package:productivity_dashboard/features/tasks/task_models.dart';
import 'package:productivity_dashboard/repositories/organization_repository.dart';
import 'package:productivity_dashboard/repositories/task_repository.dart';

void main() {
  group('project task linking', () {
    late SharedPreferences preferences;
    late OrganizationRepository organization;
    late TaskRepository tasks;
    late WorkspaceModel workspace;
    late ProjectModel firstProject;
    late ProjectModel secondProject;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      organization = OrganizationRepository(preferences);
      tasks = TaskRepository(preferences);
      final now = DateTime(2026, 8, 19);
      workspace = WorkspaceModel(
          id: 'workspace-test', name: 'Personal', createdAt: now, updatedAt: now);
      firstProject = ProjectModel(
          id: 'project-first', workspaceId: workspace.id, name: 'First');
      secondProject = ProjectModel(
          id: 'project-second', workspaceId: workspace.id, name: 'Second');
      await organization.createWorkspace(workspace);
      await organization.createProject(firstProject);
      await organization.createProject(secondProject);
    });

    TaskModel task(String id, {String? project}) => TaskModel(
        id: id,
        title: 'Task $id',
        project: project,
        workspace: workspace.id,
        createdAt: DateTime(2026, 8, 19),
        updatedAt: DateTime(2026, 8, 19));

    test('creating and moving a task updates both project link lists', () async {
      final created = await tasks.create(task('task-1', project: firstProject.id));
      var projects = await organization.loadProjects();
      expect(projects.singleWhere((item) => item.id == firstProject.id).linkedTaskIds,
          contains(created.id));

      await tasks.update(created.copyWith(project: secondProject.id));
      projects = await organization.loadProjects();
      expect(projects.singleWhere((item) => item.id == firstProject.id).linkedTaskIds,
          isNot(contains(created.id)));
      expect(projects.singleWhere((item) => item.id == secondProject.id).linkedTaskIds,
          contains(created.id));
    });

    test('deleting a task removes its project link', () async {
      final created = await tasks.create(task('task-2', project: firstProject.id));
      await tasks.remove(created);
      final project = (await organization.loadProjects())
          .singleWhere((item) => item.id == firstProject.id);
      expect(project.linkedTaskIds, isNot(contains(created.id)));
    });

    test('reconcile repairs stale project metadata from task records', () async {
      final created = await tasks.create(task('task-3', project: firstProject.id));
      final stale = (await organization.loadProjects())
          .singleWhere((item) => item.id == firstProject.id)
          .copyWith(linkedTaskIds: const []);
      await organization.saveProject(stale);
      await tasks.reconcileProjectLinks();
      final repaired = (await organization.loadProjects())
          .singleWhere((item) => item.id == firstProject.id);
      expect(repaired.linkedTaskIds, contains(created.id));
    });
  });
}
