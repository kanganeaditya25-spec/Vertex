import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'automation_models.dart';
import 'automation_providers.dart';

class AutomationPage extends ConsumerWidget {
  const AutomationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(automationControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automation Engine'),
        actions: [
          IconButton(
              tooltip: 'New workflow',
              onPressed: () => _newWorkflow(context, ref),
              icon: const Icon(Icons.add_circle_outline_rounded)),
          const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Chip(
                  avatar: Icon(Icons.offline_bolt_rounded, size: 16),
                  label: Text('Offline first'))),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Automation could not load: $error')),
        data: (value) => _AutomationShell(state: value),
      ),
    );
  }
}

class _AutomationShell extends ConsumerWidget {
  const _AutomationShell({required this.state});
  final AutomationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(automationControllerProvider.notifier);
    final sidebar = _WorkflowList(state: state);
    final content = state.tab == 'templates'
        ? _TemplatePanel(state: state)
        : state.tab == 'history'
            ? _HistoryPanel(state: state)
            : _BuilderPanel(state: state);
    return Column(children: [
      _AutomationSummary(state: state),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'builder',
                        label: Text('Builder'),
                        icon: Icon(Icons.account_tree_outlined)),
                    ButtonSegment(
                        value: 'templates',
                        label: Text('Templates'),
                        icon: Icon(Icons.copy_all_outlined)),
                    ButtonSegment(
                        value: 'history',
                        label: Text('History'),
                        icon: Icon(Icons.history_rounded))
                  ],
                  selected: {
                    state.tab
                  },
                  onSelectionChanged: (value) =>
                      controller.selectTab(value.first)))),
      const SizedBox(height: 12),
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 1050) {
          return Row(children: [
            SizedBox(width: 280, child: sidebar),
            const VerticalDivider(width: 1),
            Expanded(child: content)
          ]);
        }
        return Column(children: [
          SizedBox(height: 210, child: sidebar),
          const Divider(height: 1),
          Expanded(child: content)
        ]);
      })),
    ]);
  }
}

class _AutomationSummary extends StatelessWidget {
  const _AutomationSummary({required this.state});
  final AutomationState state;
  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
          label: 'Workflows',
          value: '${state.stats.workflowCount}',
          color: const Color(0xFF4F46E5),
          icon: Icons.account_tree_outlined),
      _SummaryCard(
          label: 'Enabled',
          value: '${state.stats.enabledWorkflowCount}',
          color: const Color(0xFF0F766E),
          icon: Icons.play_circle_outline_rounded),
      _SummaryCard(
          label: 'Successful runs',
          value: '${state.stats.successCount}',
          color: const Color(0xFF047857),
          icon: Icons.check_circle_outline_rounded),
      _SummaryCard(
          label: 'Needs approval',
          value: '${state.stats.pendingApprovalCount}',
          color: const Color(0xFFB45309),
          icon: Icons.verified_user_outlined),
    ];
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Wrap(spacing: 10, runSpacing: 10, children: cards));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: .10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w800)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowList extends ConsumerWidget {
  const _WorkflowList({required this.state});
  final AutomationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(automationControllerProvider.notifier);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                    child: Text('Workflows',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800))),
                IconButton(
                    tooltip: 'Add workflow',
                    onPressed: () => _newWorkflow(context, ref),
                    icon: const Icon(Icons.add)),
              ],
            ),
          ),
          Expanded(
            child: state.workflows.isEmpty
                ? const Center(
                    child: Text('Create your first WHEN → IF → THEN flow.'))
                : ListView(
                    children: [
                      for (final workflow in state.workflows)
                        ListTile(
                          selected: workflow.id == state.selectedWorkflowId,
                          leading: Icon(
                              workflow.enabled
                                  ? Icons.play_circle_outline_rounded
                                  : Icons.pause_circle_outline_rounded,
                              color: workflow.enabled
                                  ? const Color(0xFF0F766E)
                                  : Colors.grey),
                          title: Text(workflow.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${workflow.triggerType} · ${workflow.actions.length} action(s)'),
                          trailing: workflow.id == state.selectedWorkflowId
                              ? const Icon(Icons.chevron_right_rounded)
                              : null,
                          onTap: () => controller.selectWorkflow(workflow.id),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BuilderPanel extends ConsumerWidget {
  const _BuilderPanel({required this.state});
  final AutomationState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(automationControllerProvider.notifier);
    final workflow = state.selectedWorkflow;
    if (workflow == null) {
      return const Center(child: Text('Choose a workflow or create one.'));
    }
    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 16, 24),
        children: [
          Card(
              elevation: 0,
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              width: 8,
                              height: 56,
                              decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(workflow.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                Text(workflow.description.isEmpty
                                    ? 'No-code workflow control center'
                                    : workflow.description),
                                const SizedBox(height: 8),
                                Wrap(spacing: 8, children: [
                                  Chip(
                                      label: Text(workflow.enabled
                                          ? 'Enabled'
                                          : 'Paused')),
                                  Chip(
                                      label:
                                          Text('WHEN ${workflow.triggerType}')),
                                  Chip(
                                      label: Text(
                                          '${workflow.actions.length} THEN step(s)'))
                                ])
                              ])),
                          Switch(
                              value: workflow.enabled,
                              onChanged: (value) => controller.saveWorkflow(
                                  workflow.copyWith(enabled: value)))
                        ]),
                        const SizedBox(height: 18),
                        _FlowSection(
                            title: 'WHEN',
                            color: const Color(0xFF4F46E5),
                            icon: Icons.bolt_rounded,
                            child: Text(
                                'Trigger: ${workflow.triggerType.replaceAll('_', ' ')}',
                                style:
                                    Theme.of(context).textTheme.titleMedium)),
                        const _FlowArrow(),
                        _FlowSection(
                            title: 'IF',
                            color: const Color(0xFFB45309),
                            icon: Icons.rule_rounded,
                            child: workflow.conditions.isEmpty
                                ? const Text(
                                    'Always run; add conditions to narrow the flow.')
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                        for (final condition
                                            in workflow.conditions)
                                          Text(
                                              '${condition.field ?? condition.logical} ${condition.operator ?? ''} ${condition.value ?? ''}')
                                      ])),
                        const _FlowArrow(),
                        _FlowSection(
                            title: 'THEN',
                            color: const Color(0xFF0F766E),
                            icon: Icons.play_arrow_rounded,
                            child: _ActionList(workflow: workflow)),
                        const SizedBox(height: 18),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton.icon(
                              onPressed: () =>
                                  _addAction(context, ref, workflow),
                              icon: const Icon(Icons.add_task_rounded),
                              label: const Text('Add action')),
                          OutlinedButton.icon(
                              onPressed: () =>
                                  _addCondition(context, ref, workflow),
                              icon: const Icon(Icons.filter_alt_outlined),
                              label: const Text('Add condition')),
                          FilledButton.icon(
                              onPressed: () async {
                                final result = await controller.runSelected();
                                if (context.mounted && result != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(result.status ==
                                                  'pending_approval'
                                              ? 'Approval is required before this run.'
                                              : 'Workflow ${result.status}.')));
                                }
                              },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Run now'))
                        ]),
                      ]))),
          const SizedBox(height: 12),
          Card(
              elevation: 0,
              color: const Color(0xFFF8FAFC),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      'Safety: destructive actions pause for approval, every run is logged, retries are bounded, and workflow graphs are validated before enabling.',
                      style: Theme.of(context).textTheme.bodySmall))),
        ]);
  }
}

class _FlowSection extends StatelessWidget {
  const _FlowSection(
      {required this.title,
      required this.color,
      required this.icon,
      required this.child});
  final String title;
  final Color color;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          border: Border(left: BorderSide(color: color, width: 4)),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2))
          ]),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();
  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 30,
      child: Center(
          child: Icon(Icons.arrow_downward_rounded, color: Color(0xFF94A3B8))));
}

class _ActionList extends ConsumerWidget {
  const _ActionList({required this.workflow});
  final AutomationWorkflowModel workflow;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        for (var index = 0; index < workflow.actions.length; index++)
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  child: Text('${index + 1}')),
              title: Text(workflow.actions[index].label.isEmpty
                  ? workflow.actions[index].actionType
                  : workflow.actions[index].label),
              subtitle:
                  Text(workflow.actions[index].actionType.replaceAll('_', ' ')),
              trailing: workflow.actions[index].requiresApproval
                  ? const Icon(Icons.verified_user_outlined,
                      color: Color(0xFFB45309))
                  : const Icon(Icons.drag_handle_rounded))
      ]);
}

class _TemplatePanel extends ConsumerWidget {
  const _TemplatePanel({required this.state});
  final AutomationState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) => GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 320,
          mainAxisExtent: 170,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12),
      itemCount: state.templates.length,
      itemBuilder: (context, index) {
        final template = state.templates[index];
        return Card(
            elevation: 0,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          color: _categoryColor(template.category)),
                      const SizedBox(height: 10),
                      Text(template.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Expanded(child: Text(template.description)),
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              onPressed: () =>
                                  _useTemplate(context, ref, template),
                              child: const Text('Use template')))
                    ])));
      });
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.state});
  final AutomationState state;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        if (state.executions.isEmpty)
          const Card(
              elevation: 0,
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'No automation runs yet. Run a workflow to create an execution record.'))),
        for (final execution in state.executions)
          Card(
              elevation: 0,
              child: ListTile(
                  leading: Icon(_statusIcon(execution.status),
                      color: _statusColor(execution.status)),
                  title: Text(execution.status.replaceAll('_', ' ')),
                  subtitle: Text(
                      '${execution.actionLogs.length} action log(s) · ${execution.durationMs} ms'),
                  trailing: execution.approvalRequired
                      ? const Chip(label: Text('Approval'))
                      : null))
      ]);
}

Future<void> _newWorkflow(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  var trigger = 'manual';
  var action = 'create_task';
  final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
              title: const Text('Create workflow'),
              content: StatefulBuilder(
                  builder: (context, setState) =>
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(
                            controller: name,
                            decoration: const InputDecoration(
                                labelText: 'Workflow name')),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                            initialValue: trigger,
                            decoration: const InputDecoration(
                                labelText: 'WHEN trigger'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'manual', child: Text('Manual')),
                              DropdownMenuItem(
                                  value: 'task_completed',
                                  child: Text('Task completed')),
                              DropdownMenuItem(
                                  value: 'calendar_event_finished',
                                  child: Text('Calendar finished')),
                              DropdownMenuItem(
                                  value: 'goal_completed',
                                  child: Text('Goal completed')),
                              DropdownMenuItem(
                                  value: 'note_created',
                                  child: Text('Note created'))
                            ],
                            onChanged: (value) =>
                                setState(() => trigger = value ?? 'manual')),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                            initialValue: action,
                            decoration:
                                const InputDecoration(labelText: 'THEN action'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'create_task',
                                  child: Text('Create task')),
                              DropdownMenuItem(
                                  value: 'create_event',
                                  child: Text('Create calendar event')),
                              DropdownMenuItem(
                                  value: 'create_note',
                                  child: Text('Create note')),
                              DropdownMenuItem(
                                  value: 'send_local_notification',
                                  child: Text('Send notification')),
                              DropdownMenuItem(
                                  value: 'export_data',
                                  child: Text('Export data'))
                            ],
                            onChanged: (value) =>
                                setState(() => action = value ?? 'create_task'))
                      ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Create'))
              ]));
  if (created == true && context.mounted) {
    await ref.read(automationControllerProvider.notifier).createWorkflow(
        name: name.text, triggerType: trigger, actionType: action);
  }
}

Future<void> _addAction(BuildContext context, WidgetRef ref,
    AutomationWorkflowModel workflow) async {
  final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          SimpleDialog(title: const Text('Add THEN action'), children: [
            for (final type in [
              'create_task',
              'create_event',
              'create_note',
              'notify',
              'send_local_notification',
              'generate_ai_summary',
              'export_data'
            ])
              SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, type),
                  child: Text(type.replaceAll('_', ' ')))
          ]));
  if (action != null && context.mounted) {
    await ref
        .read(automationControllerProvider.notifier)
        .saveWorkflow(workflow.copyWith(actions: [
          ...workflow.actions,
          AutomationActionModel(
              actionType: action,
              label: action.replaceAll('_', ' '),
              order: workflow.actions.length)
        ]));
  }
}

Future<void> _addCondition(BuildContext context, WidgetRef ref,
    AutomationWorkflowModel workflow) async {
  final field = TextEditingController(text: 'priority');
  final value = TextEditingController(text: 'high');
  final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
              title: const Text('Add IF condition'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: field,
                    decoration: const InputDecoration(labelText: 'Field')),
                TextField(
                    controller: value,
                    decoration: const InputDecoration(labelText: 'Equals'))
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Add'))
              ]));
  if (added == true && context.mounted) {
    await ref
        .read(automationControllerProvider.notifier)
        .saveWorkflow(workflow.copyWith(conditions: [
          ...workflow.conditions,
          AutomationConditionModel.leaf(field.text, 'equals', value.text)
        ]));
  }
}

Future<void> _useTemplate(BuildContext context, WidgetRef ref,
    AutomationTemplateModel template) async {
  final controller = ref.read(automationControllerProvider.notifier);
  await controller.createWorkflow(
      name: template.name,
      triggerType: '${template.definition['trigger_type'] ?? 'manual'}',
      actionType: 'create_task',
      actionLabel: template.description);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${template.name} workflow created.')));
  }
}

Color _categoryColor(String category) => switch (category) {
      'planning' => const Color(0xFF4F46E5),
      'projects' => const Color(0xFF0F766E),
      'learning' => const Color(0xFF6D28D9),
      'calendar' => const Color(0xFF0369A1),
      _ => const Color(0xFFB45309)
    };
IconData _statusIcon(String status) => switch (status) {
      'success' => Icons.check_circle_outline_rounded,
      'failed' => Icons.error_outline_rounded,
      'pending_approval' => Icons.verified_user_outlined,
      _ => Icons.info_outline_rounded
    };
Color _statusColor(String status) => switch (status) {
      'success' => const Color(0xFF047857),
      'failed' => const Color(0xFFBE123C),
      'pending_approval' => const Color(0xFFB45309),
      _ => const Color(0xFF0369A1)
    };
