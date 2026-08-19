import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'graph_models.dart';
import 'graph_providers.dart';

class KnowledgeGraphPage extends ConsumerStatefulWidget {
  const KnowledgeGraphPage({super.key, this.workspaceId});

  final String? workspaceId;

  @override
  ConsumerState<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends ConsumerState<KnowledgeGraphPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.workspaceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(graphControllerProvider.notifier)
            .setWorkspace(widget.workspaceId!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(graphControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Explorer'),
        actions: [
          IconButton(
            tooltip: 'Generate relationship suggestions',
            onPressed: () => ref
                .read(graphControllerProvider.notifier)
                .generateSuggestions(),
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(
            tooltip: 'Refresh graph',
            onPressed: () =>
                ref.read(graphControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: graph.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _GraphError(message: '$error'),
        data: (state) => _GraphWorkspace(
          state: state,
          searchController: _searchController,
        ),
      ),
    );
  }
}

class _GraphWorkspace extends ConsumerWidget {
  const _GraphWorkspace({required this.state, required this.searchController});

  final GraphState state;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(graphControllerProvider.notifier);
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'One offline map for projects, tasks, notes, assets, reminders, events, and goals.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: controller.setQuery,
            decoration: const InputDecoration(
              labelText: 'Search nodes and relationships',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          _StatsRow(stats: state.stats),
          const SizedBox(height: 16),
          _ViewSelector(selected: state.view, onChanged: controller.setView),
          const SizedBox(height: 12),
          if (state.suggestions.isNotEmpty) _SuggestionsPanel(state: state),
          if (state.insights.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InsightsPanel(state: state),
          ],
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _GraphView(state: state),
            ),
          ),
          if (state.selectedNode != null) ...[
            const SizedBox(height: 12),
            _ContextPanel(state: state),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final GraphStatsModel stats;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Nodes', '${stats.totalNodes}', Icons.hub_outlined),
      ('Links', '${stats.totalRelationships}', Icons.link),
      (
        'Components',
        '${stats.connectedComponents}',
        Icons.account_tree_outlined
      ),
      ('Orphans', '${stats.orphanedNodes}', Icons.link_off),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 700
            ? (constraints.maxWidth - 24) / 4
            : (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              SizedBox(
                width: width,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    dense: true,
                    leading: Icon(value.$3),
                    title: Text(value.$1),
                    subtitle: Text(value.$2,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const views = <String, String>{
      'network': 'Network',
      'tree': 'Tree',
      'mind_map': 'Mind map',
      'timeline': 'Timeline',
      'hierarchy': 'Hierarchy',
      'table': 'Table',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        segments: [
          for (final entry in views.entries)
            ButtonSegment<String>(value: entry.key, label: Text(entry.value)),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onChanged(selection.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class _GraphView extends ConsumerWidget {
  const _GraphView({required this.state});

  final GraphState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.visibleNodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.hub_outlined, size: 48),
            SizedBox(height: 12),
            Text('No graph items match this view yet.'),
            SizedBox(height: 4),
            Text(
                'Create or open projects, tasks, notes, and assets to build context.',
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return switch (state.view) {
      'table' => _RelationshipTable(state: state),
      'timeline' => _TimelineView(state: state),
      'tree' || 'hierarchy' || 'mind_map' => _GroupedView(state: state),
      _ => _NetworkView(state: state),
    };
  }
}

class _NetworkView extends ConsumerWidget {
  const _NetworkView({required this.state});

  final GraphState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = state.visibleNodes.take(60).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 390,
          child: InteractiveViewer(
            minScale: 0.6,
            maxScale: 2.4,
            boundaryMargin: const EdgeInsets.all(80),
            child: SizedBox(
              width: 760,
              height: 390,
              child: CustomPaint(
                painter: _GraphPainter(
                    nodes: nodes, relationships: state.visibleRelationships),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('Select a node to expand its context and backlinks.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        _NodeChips(nodes: nodes),
      ],
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({required this.nodes, required this.relationships});

  final List<GraphNodeModel> nodes;
  final List<GraphRelationshipModel> relationships;

  Offset _position(int index) {
    final column = index % 5;
    final row = index ~/ 5;
    return Offset(86 + column * 145, 68 + row * 105);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final positions = <String, Offset>{};
    for (var index = 0; index < nodes.length; index++) {
      positions[nodes[index].id] = _position(index);
    }
    final line = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    for (final relationship in relationships) {
      final source = positions[relationship.sourceNodeId];
      final target = positions[relationship.targetNodeId];
      if (source != null && target != null) {
        canvas.drawLine(source, target, line);
      }
    }
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final position = _position(index);
      final fill = Paint()..color = _colorFor(node.entityType);
      canvas.drawCircle(position, 26, fill);
      final label = TextPainter(
        text: TextSpan(
            text: node.label.length > 16
                ? '${node.label.substring(0, 16)}…'
                : node.label,
            style: const TextStyle(fontSize: 11, color: Colors.black87)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 128);
      label.paint(canvas, position + const Offset(-64, 34));
    }
  }

  Color _colorFor(String type) => switch (type) {
        'project' => Colors.indigo.shade200,
        'task' => Colors.teal.shade200,
        'note' => Colors.amber.shade300,
        'asset' => Colors.orange.shade200,
        'reminder' => Colors.red.shade200,
        'calendar_event' => Colors.green.shade200,
        'goal' => Colors.purple.shade200,
        _ => Colors.blueGrey.shade200,
      };

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.nodes != nodes || oldDelegate.relationships != relationships;
}

class _NodeChips extends ConsumerWidget {
  const _NodeChips({required this.nodes});
  final List<GraphNodeModel> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final node in nodes)
            ActionChip(
              avatar: Icon(_iconFor(node.entityType), size: 16),
              label: Text(node.label),
              onPressed: () => ref
                  .read(graphControllerProvider.notifier)
                  .selectNode(node.id),
            ),
        ],
      );

  IconData _iconFor(String type) => switch (type) {
        'project' => Icons.folder_outlined,
        'task' => Icons.check_circle_outline,
        'note' => Icons.notes_outlined,
        'asset' => Icons.description_outlined,
        'reminder' => Icons.notifications_none,
        'calendar_event' => Icons.event_outlined,
        'goal' => Icons.flag_outlined,
        _ => Icons.circle_outlined,
      };
}

class _GroupedView extends ConsumerWidget {
  const _GroupedView({required this.state});
  final GraphState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <String, List<GraphNodeModel>>{};
    for (final node in state.visibleNodes) {
      groups.putIfAbsent(node.entityType, () => []).add(node);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(entry.key.replaceAll('_', ' ').toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge)),
          for (final node in entry.value)
            ListTile(
              dense: true,
              leading: CircleAvatar(child: Text('${node.degree}')),
              title: Text(node.label),
              subtitle: Text(
                  node.contentText.isEmpty
                      ? 'No description'
                      : node.contentText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              onTap: () => ref
                  .read(graphControllerProvider.notifier)
                  .selectNode(node.id),
            ),
        ],
      ],
    );
  }
}

class _TimelineView extends ConsumerWidget {
  const _TimelineView({required this.state});
  final GraphState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = [...state.visibleNodes]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return Column(
      children: [
        for (final node in nodes)
          ListTile(
            leading: CircleAvatar(child: Text('${node.degree}')),
            title: Text(node.label),
            subtitle: Text('${node.entityType} · ${_format(node.updatedAt)}'),
            onTap: () =>
                ref.read(graphControllerProvider.notifier).selectNode(node.id),
          ),
      ],
    );
  }

  String _format(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _RelationshipTable extends StatelessWidget {
  const _RelationshipTable({required this.state});
  final GraphState state;

  @override
  Widget build(BuildContext context) {
    final names = {for (final node in state.nodes) node.id: node.label};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('From')),
          DataColumn(label: Text('Relationship')),
          DataColumn(label: Text('To')),
          DataColumn(label: Text('Source'))
        ],
        rows: [
          for (final relationship in state.visibleRelationships)
            DataRow(cells: [
              DataCell(Text(names[relationship.sourceNodeId] ??
                  relationship.sourceNodeId)),
              DataCell(
                  Text(relationship.relationshipType.replaceAll('_', ' '))),
              DataCell(Text(names[relationship.targetNodeId] ??
                  relationship.targetNodeId)),
              DataCell(Text(relationship.source)),
            ]),
        ],
      ),
    );
  }
}

class _SuggestionsPanel extends ConsumerWidget {
  const _SuggestionsPanel({required this.state});
  final GraphState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = {for (final node in state.nodes) node.id: node.label};
    final controller = ref.read(graphControllerProvider.notifier);
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suggested connections',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final suggestion in state.suggestions.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${names[suggestion.sourceNodeId] ?? 'Item'} → ${names[suggestion.targetNodeId] ?? 'Item'}'),
                subtitle: Text(
                    '${suggestion.explanation} Confidence ${(suggestion.score * 100).round()}%.'),
                trailing: Wrap(
                  children: [
                    IconButton(
                        tooltip: 'Accept connection',
                        onPressed: () =>
                            controller.acceptSuggestion(suggestion),
                        icon: const Icon(Icons.check)),
                    IconButton(
                        tooltip: 'Dismiss suggestion',
                        onPressed: () =>
                            controller.dismissSuggestion(suggestion),
                        icon: const Icon(Icons.close)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({required this.state});
  final GraphState state;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        title: const Text('Graph insights'),
        leading: const Icon(Icons.insights_outlined),
        children: [
          for (final insight in state.insights)
            ListTile(
              title: Text(insight.title),
              subtitle: Text(insight.explanation),
              trailing: Text(
                  insight.score == 0 ? '' : insight.score.toStringAsFixed(0)),
            ),
        ],
      );
}

class _ContextPanel extends ConsumerWidget {
  const _ContextPanel({required this.state});
  final GraphState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = state.selectedNode!;
    final relationships = state.relationships
        .where((relationship) =>
            relationship.sourceNodeId == selected.id ||
            relationship.targetNodeId == selected.id)
        .toList();
    final names = {for (final node in state.nodes) node.id: node.label};
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.account_tree_outlined),
        title: Text(selected.label),
        subtitle:
            Text('${selected.entityType} · ${selected.degree} direct links'),
        children: [
          if (selected.contentText.isNotEmpty)
            ListTile(title: Text(selected.contentText)),
          for (final relationship in relationships)
            ListTile(
              dense: true,
              leading: Icon(relationship.sourceNodeId == selected.id
                  ? Icons.call_made
                  : Icons.call_received),
              title: Text(
                  '${relationship.relationshipType.replaceAll('_', ' ')} · ${names[relationship.sourceNodeId == selected.id ? relationship.targetNodeId : relationship.sourceNodeId] ?? 'Related item'}'),
              subtitle: Text(relationship.explanation.isEmpty
                  ? 'No explanation provided.'
                  : relationship.explanation),
            ),
          if (relationships.isEmpty)
            const ListTile(title: Text('No incoming or outgoing links yet.')),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                onPressed: () =>
                    ref.read(graphControllerProvider.notifier).selectNode(null),
                icon: const Icon(Icons.close),
                label: const Text('Close context')),
          ),
        ],
      ),
    );
  }
}

class _GraphError extends StatelessWidget {
  const _GraphError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('Knowledge Graph could not load'),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
