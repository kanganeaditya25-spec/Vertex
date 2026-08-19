import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'search_models.dart';
import 'search_providers.dart';

class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage(
      {super.key, this.palette = false, this.workspaceId = ''});

  final bool palette;
  final String workspaceId;

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _queryController = TextEditingController();
  final _queryFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.palette) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _queryFocus.requestFocus();
        ref.read(searchControllerProvider.notifier).refreshCommands('');
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.palette ? 'Command Palette' : 'Global Search'),
        actions: [
          if (!widget.palette)
            IconButton(
              tooltip: 'Open Command Palette',
              onPressed: () => context.push('/search?palette=1'),
              icon: const Icon(Icons.keyboard_command_key_outlined),
            ),
          IconButton(
            tooltip: 'Refresh search index',
            onPressed: () =>
                ref.read(searchControllerProvider.notifier).searchNow(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: search.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Search could not load: $error')),
        data: (state) => _SearchBody(
          state: state,
          palette: widget.palette,
          queryController: _queryController,
          queryFocus: _queryFocus,
        ),
      ),
    );
  }
}

class _SearchBody extends ConsumerWidget {
  const _SearchBody(
      {required this.state,
      required this.palette,
      required this.queryController,
      required this.queryFocus});

  final SearchState state;
  final bool palette;
  final TextEditingController queryController;
  final FocusNode queryFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(searchControllerProvider.notifier);
    return RefreshIndicator(
      onRefresh: () => controller.searchNow(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TextField(
            controller: queryController,
            focusNode: queryFocus,
            autofocus: palette,
            onChanged:
                palette ? controller.refreshCommands : controller.setQuery,
            onSubmitted: (_) =>
                controller.searchNow(searchType: state.searchType),
            decoration: InputDecoration(
              labelText: palette
                  ? 'Type a command or search everything'
                  : 'Search everything',
              hintText: 'Try “Show all React projects” or “Find PDFs about AI”',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Run search',
                onPressed: () =>
                    controller.searchNow(searchType: state.searchType),
                icon: const Icon(Icons.arrow_forward),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (!palette) ...[
            _SearchModeSelector(
                selected: state.searchType,
                onChanged: (value) => controller.searchNow(searchType: value)),
            const SizedBox(height: 10),
            _FilterBar(
                filters: state.filters, onChanged: controller.setFilters),
            const SizedBox(height: 12),
          ],
          if (palette) _CommandList(commands: state.commands),
          if (!palette && state.query.trim().isEmpty && state.results.isEmpty)
            _SearchLanding(state: state),
          if (!palette && state.query.trim().isNotEmpty) ...[
            _ResultHeader(state: state),
            for (final result in state.results) _ResultCard(result: result),
            if (state.results.isEmpty) const _EmptySearch(),
          ],
          if (!palette && state.collections.isNotEmpty) ...[
            const SizedBox(height: 16),
            _CollectionsPanel(collections: state.collections),
          ],
          if (state.studyResource != null) ...[
            const SizedBox(height: 16),
            _StudyPanel(resource: state.studyResource!),
          ],
          if (state.discovery != null) ...[
            const SizedBox(height: 16),
            _DiscoveryPanel(discovery: state.discovery!),
          ],
        ],
      ),
    );
  }
}

class _SearchModeSelector extends StatelessWidget {
  const _SearchModeSelector({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<String>(
        segments: const [
          ButtonSegment(
              value: 'keyword',
              label: Text('Keyword'),
              icon: Icon(Icons.text_fields)),
          ButtonSegment(
              value: 'semantic',
              label: Text('Semantic'),
              icon: Icon(Icons.hub_outlined)),
          ButtonSegment(
              value: 'ai',
              label: Text('AI intent'),
              icon: Icon(Icons.auto_awesome_outlined)),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onChanged(selection.first),
        showSelectedIcon: false,
      );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filters, required this.onChanged});
  final SearchFiltersModel filters;
  final ValueChanged<SearchFiltersModel> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('Recent'),
            selected: filters.recentOnly,
            onSelected: (selected) =>
                onChanged(filters.copyWith(recentOnly: selected)),
          ),
          for (final type in const [
            'project',
            'task',
            'note',
            'asset',
            'reminder'
          ])
            FilterChip(
              label: Text(type),
              selected: filters.sourceTypes.contains(type),
              onSelected: (selected) {
                final types = [...filters.sourceTypes];
                if (selected) {
                  types.add(type);
                } else {
                  types.remove(type);
                }
                onChanged(filters.copyWith(sourceTypes: types));
              },
            ),
          if (filters.workspaceId.isNotEmpty)
            InputChip(
                label: Text('Workspace: ${filters.workspaceId}'),
                onDeleted: () => onChanged(filters.copyWith(workspaceId: ''))),
        ],
      );
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.state});
  final SearchState state;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text('${state.results.length} results',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(state.searchType,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.result});
  final SearchResultModel result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(searchControllerProvider.notifier);
    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(child: Icon(_iconFor(result.sourceType))),
        title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(result.preview.isEmpty ? result.snippet : result.preview,
            maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<String>(
          tooltip: 'Quick actions',
          onSelected: (action) async {
            if (action == 'study') {
              await controller.runStudy(
                  source: result,
                  text: result.preview,
                  resourceType: 'revision_notes');
            } else if (action == 'discover') {
              await controller.discover(result);
            } else if (action == 'save') {
              await controller.saveCurrentSearch(name: result.title);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'study', child: Text('Create study notes')),
            PopupMenuItem(
                value: 'discover', child: Text('Discover related items')),
            PopupMenuItem(value: 'save', child: Text('Save current search')),
          ],
        ),
        onTap: () => _openResult(context, result),
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'project' => Icons.folder_outlined,
        'task' => Icons.check_circle_outline,
        'note' => Icons.notes_outlined,
        'asset' => Icons.description_outlined,
        'reminder' => Icons.notifications_none,
        'calendar_event' => Icons.event_outlined,
        'goal' => Icons.flag_outlined,
        _ => Icons.search,
      };

  void _openResult(BuildContext context, SearchResultModel result) {
    final route = switch (result.sourceType) {
      'project' => '/organization',
      'task' => '/tasks',
      'note' => '/notes',
      'asset' => '/assets',
      'reminder' => '/reminders',
      'calendar_event' => '/calendar',
      'assistant_conversation' => '/assistant',
      _ => '/knowledge-graph',
    };
    context.push(route);
  }
}

class _CommandList extends ConsumerWidget {
  const _CommandList({required this.commands});
  final List<CommandItemModel> commands;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(searchControllerProvider.notifier);
    if (commands.isEmpty) {
      return const _EmptySearch(message: 'No commands match this input.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Commands', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final command in commands)
          Card(
            child: ListTile(
              leading: Icon(_iconFor(command.icon)),
              title: Text(command.title),
              subtitle: Text('${command.category} · ${command.subtitle}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (command.route.isNotEmpty) context.push(command.route);
                controller.refreshCommands('');
              },
            ),
          ),
      ],
    );
  }

  IconData _iconFor(String icon) => switch (icon) {
        'dashboard' => Icons.dashboard_outlined,
        'checklist' => Icons.checklist,
        'calendar' => Icons.calendar_month_outlined,
        'notes' => Icons.notes_outlined,
        'folder' => Icons.folder_outlined,
        'asset' => Icons.folder_copy_outlined,
        'hub' => Icons.hub_outlined,
        'notifications' => Icons.notifications_none,
        'timer' => Icons.timer_outlined,
        'assistant' => Icons.auto_awesome_outlined,
        _ => Icons.circle_outlined,
      };
}

class _SearchLanding extends ConsumerWidget {
  const _SearchLanding({required this.state});
  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Search and discover',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
              'Search tasks, calendar events, projects, notes, assets, reminders, graph entities, and study resources from one place.'),
          const SizedBox(height: 18),
          if (state.history.isNotEmpty) ...[
            Text('Recent searches',
                style: Theme.of(context).textTheme.titleMedium),
            for (final item in state.history.take(6))
              ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(item.query),
                  subtitle: Text('${item.resultCount} results'),
                  onTap: () {
                    ref
                        .read(searchControllerProvider.notifier)
                        .setQuery(item.query);
                  }),
          ],
          const SizedBox(height: 12),
          const _OpenSourceNote(),
        ],
      );
}

class _OpenSourceNote extends StatelessWidget {
  const _OpenSourceNote();

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const ListTile(
          leading: Icon(Icons.offline_bolt_outlined),
          title: Text('Offline-first discovery'),
          subtitle: Text(
              'Keyword, fuzzy, metadata, tag, graph, and deterministic study extraction work without a paid API or telemetry.'),
        ),
      );
}

class _CollectionsPanel extends StatelessWidget {
  const _CollectionsPanel({required this.collections});
  final List<SmartCollectionModel> collections;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        leading: const Icon(Icons.collections_bookmark_outlined),
        title: const Text('Smart collections'),
        children: [
          for (final collection in collections)
            ListTile(
                title: Text(collection.name),
                subtitle: Text(
                    '${collection.itemIds.length} items · ${collection.description}'),
                trailing: collection.aiRecommended
                    ? const Icon(Icons.auto_awesome_outlined)
                    : null),
        ],
      );
}

class _StudyPanel extends StatelessWidget {
  const _StudyPanel({required this.resource});
  final StudyResourceModel resource;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.school_outlined),
          title: Text(
              '${resource.title} · ${resource.resourceType.replaceAll('_', ' ')}'),
          subtitle: Text(resource.content['summary']?.toString() ?? ''),
          children: [
            for (final entry in resource.content.entries.take(7))
              ListTile(
                  title: Text(entry.key.replaceAll('_', ' ')),
                  subtitle: Text('${entry.value}')),
          ],
        ),
      );
}

class _DiscoveryPanel extends StatelessWidget {
  const _DiscoveryPanel({required this.discovery});
  final DiscoveryModel discovery;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.explore_outlined),
          title: const Text('Knowledge discovery'),
          subtitle: Text('${discovery.relatedResults.length} related items'),
          children: [
            for (final result in discovery.relatedResults.take(8))
              ListTile(
                  title: Text(result.title), subtitle: Text(result.sourceType)),
            for (final collection in discovery.recommendedCollections)
              ListTile(
                  leading: const Icon(Icons.collections_bookmark_outlined),
                  title: Text(collection)),
          ],
        ),
      );
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({this.message = 'No results found.'});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        const Icon(Icons.search_off, size: 48),
        const SizedBox(height: 10),
        Text(message)
      ]));
}
