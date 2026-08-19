import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_models.dart';
import 'settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Personalization'),
        actions: [
          IconButton(
              tooltip: 'Export settings',
              onPressed: () => _exportSettings(context, ref),
              icon: const Icon(Icons.file_download_outlined)),
          IconButton(
              tooltip: 'Create local backup',
              onPressed: () => _createBackup(context, ref),
              icon: const Icon(Icons.backup_outlined)),
          const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Chip(
                  avatar: Icon(Icons.lock_outline_rounded, size: 16),
                  label: Text('Stored locally'))),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Settings could not load: $error')),
        data: (state) => _SettingsShell(state: state),
      ),
    );
  }
}

class _SettingsShell extends ConsumerWidget {
  const _SettingsShell({required this.state});
  final SettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final categories = settingsCategories;
    final filtered = state.searchQuery.trim().isEmpty
        ? categories
        : categories
            .where((item) =>
                item.label
                    .toLowerCase()
                    .contains(state.searchQuery.toLowerCase()) ||
                item.description
                    .toLowerCase()
                    .contains(state.searchQuery.toLowerCase()) ||
                item.fields.any((field) => field.label
                    .toLowerCase()
                    .contains(state.searchQuery.toLowerCase())))
            .toList();
    final category = categories
            .where((item) => item.id == state.selectedCategory)
            .firstOrNull ??
        categories.first;
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .setSearchQuery(value),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search settings, categories, or controls',
                  border: OutlineInputBorder()))),
      Expanded(
          child: width >= 900
              ? Row(children: [
                  SizedBox(
                      width: 290,
                      child: _CategoryList(
                          categories: filtered,
                          selected: state.selectedCategory)),
                  const VerticalDivider(width: 1),
                  Expanded(
                      child: _SettingsContent(category: category, state: state))
                ])
              : Column(children: [
                  SizedBox(
                      height: 196,
                      child: _CategoryList(
                          categories: filtered,
                          selected: state.selectedCategory,
                          horizontal: true)),
                  const Divider(height: 1),
                  Expanded(
                      child: _SettingsContent(category: category, state: state))
                ])),
    ]);
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList(
      {required this.categories,
      required this.selected,
      this.horizontal = false});
  final List<SettingsCategoryModel> categories;
  final String selected;
  final bool horizontal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ListView.builder(
        scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
        padding: const EdgeInsets.all(12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final active = category.id == selected;
          return Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 6),
              child: SizedBox(
                  width: horizontal ? 190 : null,
                  child: ListTile(
                      selected: active,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      leading: Icon(_iconFor(category.icon),
                          color: active ? const Color(0xFF4F46E5) : null),
                      title: Text(category.label),
                      subtitle: horizontal
                          ? null
                          : Text(category.description,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => ref
                          .read(settingsControllerProvider.notifier)
                          .selectCategory(category.id))));
        });
    return Card(elevation: 0, margin: const EdgeInsets.all(12), child: content);
  }
}

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent({required this.category, required this.state});
  final SettingsCategoryModel category;
  final SettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 20, 32),
        children: [
          Row(children: [
            Container(
                width: 8,
                height: 56,
                decoration: BoxDecoration(
                    color: _accentFor(category.id),
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(category.label,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(category.description)
                ])),
            IconButton(
                tooltip: 'Favorite category',
                onPressed: () => controller.updateSetting(
                    'settings_favorite_${category.id}', true),
                icon: const Icon(Icons.star_border_rounded))
          ]),
          const SizedBox(height: 18),
          if (category.id == 'backup') _BackupPanel(state: state),
          if (category.id == 'privacy') _PrivacyPanel(state: state),
          if (category.id == 'storage') _StoragePanel(state: state),
          if (category.id == 'about') const _AboutPanel(),
          if (category.id == 'developer') _DeveloperPanel(state: state),
          for (final field in category.fields)
            _SettingField(field: field, state: state),
          if (category.id == 'appearance') _AppearancePreview(state: state),
        ]);
  }
}

class _SettingField extends ConsumerWidget {
  const _SettingField({required this.field, required this.state});
  final SettingsFieldModel field;
  final SettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final value = state.snapshot.valueAt(field.path);
    if (field.type == 'bool') {
      return Card(
        elevation: 0,
        child: SwitchListTile(
          title: Text(field.label),
          subtitle: Text(field.description),
          value: value == true,
          onChanged: (next) => controller.updateSetting(field.path, next),
        ),
      );
    }
    if (field.type == 'select') {
      final selected = field.options.contains('$value')
          ? '$value'
          : field.options.firstOrNull;
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: InputDecoration(
                labelText: field.label, helperText: field.description),
            items: [
              for (final option in field.options)
                DropdownMenuItem(
                    value: option,
                    child: Text(option.replaceAll('_', ' ').toUpperCase()))
            ],
            onChanged: (next) {
              if (next != null) {
                controller.updateSetting(field.path, next);
              }
            },
          ),
        ),
      );
    }
    if (field.type == 'number') {
      final numeric = (value is num ? value : 0).toDouble().clamp(0, 100);
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.label, style: Theme.of(context).textTheme.titleMedium),
              Text(field.description,
                  style: Theme.of(context).textTheme.bodySmall),
              Row(children: [
                Expanded(
                    child: Slider(
                        value: numeric.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${numeric.round()}',
                        onChanged: (next) => controller.updateSetting(
                            field.path, next.round()))),
                Text('${numeric.round()}')
              ]),
            ],
          ),
        ),
      );
    }
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: TextFormField(
            initialValue: value?.toString() ?? '',
            decoration: InputDecoration(
                labelText: field.label, helperText: field.description),
            onChanged: (next) => controller.updateSetting(field.path, next)),
      ),
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.state});
  final SettingsState state;
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: _accentFor(state.accentColor),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.palette_outlined, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    'Preview updates immediately. Theme: ${state.themeMode}; accent: ${state.accentColor}; text scale: ${state.fontScale.toStringAsFixed(1)}x.'))
          ])));
}

class _BackupPanel extends ConsumerWidget {
  const _BackupPanel({required this.state});
  final SettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Local backups',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
                'Backups are verified JSON snapshots stored on this device. Scheduled backup settings are evaluated when the app is active or resumes.'),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: () => _createBackup(context, ref),
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Create backup')),
            const SizedBox(height: 8),
            for (final backup in state.backups)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    backup.verified
                        ? Icons.verified_outlined
                        : Icons.warning_amber_rounded,
                    color: backup.verified
                        ? const Color(0xFF047857)
                        : const Color(0xFFB45309)),
                title: Text(backup.label),
                subtitle: Text(
                    '${backup.sizeBytes} bytes · ${backup.createdAt ?? 'local'}'),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .restoreBackup(backup.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Backup restored locally.')));
                    }
                  },
                  child: const Text('Restore'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyPanel extends ConsumerWidget {
  const _PrivacyPanel({required this.state});
  final SettingsState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Privacy controls',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
                'Telemetry is disabled by default. Destructive local actions require confirmation.'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                  onPressed: () => _confirmPrivacy(context, ref,
                      'clear_search_history', 'Delete search history?'),
                  child: const Text('Clear search history')),
              OutlinedButton(
                  onPressed: () => _confirmPrivacy(context, ref,
                      'clear_ai_memory', 'Clear local AI memory?'),
                  child: const Text('Clear AI memory')),
              OutlinedButton(
                  onPressed: () => _confirmPrivacy(
                      context, ref, 'clear_cache', 'Clear local cache?'),
                  child: const Text('Clear cache'))
            ])
          ])));
}

class _StoragePanel extends StatelessWidget {
  const _StoragePanel({required this.state});
  final SettingsState state;
  @override
  Widget build(BuildContext context) {
    final rows = {
      'Settings': state.storage.settingsBytes,
      'Backups': state.storage.backupBytes,
      'Database': state.storage.databaseBytes,
      'Cache': state.storage.cacheBytes,
      'AI models': state.storage.modelBytes
    };
    return Card(
        elevation: 0,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Storage overview',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final entry in rows.entries)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    trailing: Text(_formatBytes(entry.value)))
            ])));
  }
}

class _DeveloperPanel extends ConsumerWidget {
  const _DeveloperPanel({required this.state});
  final SettingsState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Developer tools',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
                'Developer diagnostics are hidden until Developer Mode is enabled.'),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Developer Mode'),
                value:
                    state.snapshot.valueAt('developer.enabled', false) == true,
                onChanged: (value) => ref
                    .read(settingsControllerProvider.notifier)
                    .updateSetting('developer.enabled', value)),
            if (state.snapshot.valueAt('developer.enabled', false) == true)
              const ListTile(
                  leading: Icon(Icons.bug_report_outlined),
                  title: Text('Debug logs and event bus monitor ready'),
                  subtitle:
                      Text('Local diagnostics only; no telemetry is sent.'))
          ])));
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FocusFlow AI',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Offline-first productivity workspace'),
            SizedBox(height: 4),
            Text(
                'Open-source architecture with local persistence, local AI integration points, and no telemetry by default.'),
            SizedBox(height: 12),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.code_rounded),
                title: Text('Build 0.1.0+1')),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.shield_outlined),
                title: Text('Privacy-first by design')),
          ],
        ),
      ),
    );
  }
}

Future<void> _createBackup(BuildContext context, WidgetRef ref) async {
  final backup =
      await ref.read(settingsControllerProvider.notifier).createBackup();
  if (context.mounted && backup != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup created: ${backup.label}')),
    );
  }
}

Future<void> _exportSettings(BuildContext context, WidgetRef ref) async {
  final payload =
      await ref.read(settingsControllerProvider.notifier).exportSettings();
  await Clipboard.setData(ClipboardData(text: payload));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings JSON copied to clipboard.')),
    );
  }
}

Future<void> _confirmPrivacy(
    BuildContext context, WidgetRef ref, String action, String title) async {
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
              title: Text(title),
              content: const Text(
                  'This changes local data and cannot be undone from the settings screen.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Confirm'))
              ]));
  if (confirmed == true && context.mounted) {
    await ref.read(settingsControllerProvider.notifier).privacyAction(action);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy action completed locally.')),
      );
    }
  }
}

String _formatBytes(int value) => value < 1024
    ? '$value B'
    : value < 1024 * 1024
        ? '${(value / 1024).toStringAsFixed(1)} KB'
        : '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
IconData _iconFor(String name) => switch (name) {
      'person' => Icons.person_outline_rounded,
      'palette' => Icons.palette_outlined,
      'smart_toy' => Icons.smart_toy_outlined,
      'bolt' => Icons.bolt_outlined,
      'calendar' => Icons.calendar_month_outlined,
      'task' => Icons.checklist_outlined,
      'note' => Icons.menu_book_outlined,
      'project' => Icons.account_tree_outlined,
      'analytics' => Icons.insights_outlined,
      'automation' => Icons.account_tree_outlined,
      'notifications' => Icons.notifications_none_rounded,
      'reminder' => Icons.alarm_outlined,
      'search' => Icons.search_rounded,
      'mic' => Icons.mic_none_rounded,
      'security' => Icons.lock_outline_rounded,
      'privacy' => Icons.shield_outlined,
      'backup' => Icons.backup_outlined,
      'storage' => Icons.storage_outlined,
      'accessibility' => Icons.accessibility_new_outlined,
      'language' => Icons.language_outlined,
      'integration' => Icons.extension_outlined,
      'developer' => Icons.developer_mode_outlined,
      _ => Icons.info_outline_rounded
    };
Color _accentFor(String name) => switch (name) {
      'indigo' => const Color(0xFF4F46E5),
      'teal' => const Color(0xFF0F766E),
      'amber' => const Color(0xFFB45309),
      'blue' => const Color(0xFF0369A1),
      'violet' => const Color(0xFF6D28D9),
      'rose' => const Color(0xFFBE123C),
      'general' => const Color(0xFF4F46E5),
      'appearance' => const Color(0xFF6D28D9),
      'ai' => const Color(0xFF0369A1),
      'productivity' => const Color(0xFF0F766E),
      'privacy' => const Color(0xFFBE123C),
      _ => const Color(0xFF475569)
    };

const settingsCategories = <SettingsCategoryModel>[
  SettingsCategoryModel(
      id: 'general',
      label: 'General',
      icon: 'person',
      description: 'Profile, locale, workspace, and date preferences',
      fields: [
        SettingsFieldModel(
            path: 'general.display_name',
            label: 'Display name',
            description: 'Shown in your workspace',
            type: 'text'),
        SettingsFieldModel(
            path: 'general.timezone',
            label: 'Timezone',
            description: 'Used for schedules and date calculations',
            type: 'select',
            options: [
              'UTC',
              'Asia/Kolkata',
              'America/New_York',
              'Europe/London'
            ]),
        SettingsFieldModel(
            path: 'general.time_format',
            label: 'Time format',
            description: 'Choose 12 or 24 hour display',
            type: 'select',
            options: ['12h', '24h'])
      ]),
  SettingsCategoryModel(
      id: 'appearance',
      label: 'Appearance',
      icon: 'palette',
      description: 'Theme, accent, typography, density, and motion',
      fields: [
        SettingsFieldModel(
            path: 'appearance.theme_mode',
            label: 'Theme',
            description: 'Applied immediately',
            type: 'select',
            options: ['system', 'light', 'dark']),
        SettingsFieldModel(
            path: 'appearance.accent_color',
            label: 'Accent color',
            description: 'Flat solid accent used across the app',
            type: 'select',
            options: ['indigo', 'teal', 'amber', 'blue', 'violet', 'rose']),
        SettingsFieldModel(
            path: 'appearance.font_scale',
            label: 'Font scale',
            description: 'Accessibility-friendly text scale',
            type: 'number')
      ]),
  SettingsCategoryModel(
      id: 'ai',
      label: 'AI',
      icon: 'smart_toy',
      description: 'Local models, memory, personality, and AI behaviors',
      fields: [
        SettingsFieldModel(
            path: 'ai.local_model',
            label: 'Default local model',
            description: 'Used when a local model is available',
            type: 'text'),
        SettingsFieldModel(
            path: 'ai.ollama_endpoint',
            label: 'Ollama endpoint',
            description: 'Local endpoint only',
            type: 'text'),
        SettingsFieldModel(
            path: 'ai.personality',
            label: 'AI personality',
            description: 'Response style',
            type: 'select',
            options: ['focused', 'coach', 'concise', 'researcher']),
        SettingsFieldModel(
            path: 'ai.auto_scheduling',
            label: 'Auto scheduling',
            description: 'Allow local scheduling suggestions',
            type: 'bool'),
        SettingsFieldModel(
            path: 'ai.suggestions',
            label: 'AI suggestions',
            description: 'Show explainable local suggestions',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'productivity',
      label: 'Productivity',
      icon: 'bolt',
      description: 'Work hours, focus sessions, goals, and defaults',
      fields: [
        SettingsFieldModel(
            path: 'productivity.work_start',
            label: 'Work starts',
            description: 'Default workday start',
            type: 'text'),
        SettingsFieldModel(
            path: 'productivity.work_end',
            label: 'Work ends',
            description: 'Default workday end',
            type: 'text'),
        SettingsFieldModel(
            path: 'productivity.focus_minutes',
            label: 'Focus duration',
            description: 'Minutes per focus block',
            type: 'number'),
        SettingsFieldModel(
            path: 'productivity.daily_goal',
            label: 'Daily task goal',
            description: 'Target completed tasks',
            type: 'number')
      ]),
  SettingsCategoryModel(
      id: 'calendar',
      label: 'Calendar',
      icon: 'calendar',
      description: 'Working days, buffers, views, and meeting defaults',
      fields: [
        SettingsFieldModel(
            path: 'calendar.default_view',
            label: 'Default view',
            description: 'Calendar opening view',
            type: 'select',
            options: ['day', 'week', 'month']),
        SettingsFieldModel(
            path: 'calendar.buffer_minutes',
            label: 'Buffer minutes',
            description: 'Time between meetings',
            type: 'number')
      ]),
  SettingsCategoryModel(
      id: 'tasks',
      label: 'Tasks',
      icon: 'task',
      description: 'Task defaults, sorting, and completion behavior',
      fields: [
        SettingsFieldModel(
            path: 'tasks.default_priority',
            label: 'Default priority',
            description: 'New task priority',
            type: 'select',
            options: ['low', 'medium', 'high', 'urgent']),
        SettingsFieldModel(
            path: 'tasks.default_category',
            label: 'Default category',
            description: 'New task category',
            type: 'text'),
        SettingsFieldModel(
            path: 'tasks.auto_archive',
            label: 'Auto archive',
            description: 'Archive completed tasks by rule',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'notes',
      label: 'Notes',
      icon: 'note',
      description: 'Editor, markdown, autosave, and version history',
      fields: [
        SettingsFieldModel(
            path: 'notes.default_editor',
            label: 'Default editor',
            description: 'Editor mode',
            type: 'select',
            options: ['markdown', 'rich_text']),
        SettingsFieldModel(
            path: 'notes.auto_save_seconds',
            label: 'Auto-save interval',
            description: 'Seconds between local saves',
            type: 'number'),
        SettingsFieldModel(
            path: 'notes.version_history',
            label: 'Version history',
            description: 'Keep local note versions',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'projects',
      label: 'Projects',
      icon: 'project',
      description: 'Workspace defaults, statuses, milestones, and templates',
      fields: [
        SettingsFieldModel(
            path: 'projects.default_status',
            label: 'Default status',
            description: 'New project status',
            type: 'select',
            options: ['planning', 'active', 'on_hold', 'completed']),
        SettingsFieldModel(
            path: 'projects.milestone_rules',
            label: 'Milestone rules',
            description: 'Use milestone progress rules',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'analytics',
      label: 'Analytics',
      icon: 'analytics',
      description: 'Privacy-aware productivity insights',
      fields: [
        SettingsFieldModel(
            path: 'analytics.enabled',
            label: 'Enable analytics',
            description: 'Compute local metrics',
            type: 'bool'),
        SettingsFieldModel(
            path: 'analytics.default_period',
            label: 'Default period',
            description: 'Opening analytics period',
            type: 'select',
            options: ['day', 'week', 'month', 'year'])
      ]),
  SettingsCategoryModel(
      id: 'automation',
      label: 'Automation',
      icon: 'automation',
      description: 'Workflow execution safety and limits',
      fields: [
        SettingsFieldModel(
            path: 'automation.enabled',
            label: 'Enable automation',
            description: 'Allow local workflows',
            type: 'bool'),
        SettingsFieldModel(
            path: 'automation.require_approval',
            label: 'Require approval',
            description: 'Pause destructive actions',
            type: 'bool'),
        SettingsFieldModel(
            path: 'automation.max_steps',
            label: 'Maximum steps',
            description: 'Bound each workflow run',
            type: 'number')
      ]),
  SettingsCategoryModel(
      id: 'notifications',
      label: 'Notifications',
      icon: 'notifications',
      description: 'Local notification behavior and quiet hours',
      fields: [
        SettingsFieldModel(
            path: 'notifications.local_enabled',
            label: 'Local notifications',
            description: 'Allow device notifications',
            type: 'bool'),
        SettingsFieldModel(
            path: 'notifications.silent_mode',
            label: 'Silent mode',
            description: 'Suppress non-critical notifications',
            type: 'bool'),
        SettingsFieldModel(
            path: 'notifications.do_not_disturb',
            label: 'Do not disturb',
            description: 'Respect quiet hours',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'reminders',
      label: 'Reminders',
      icon: 'reminder',
      description: 'Snooze, repeat, and smart reminder defaults',
      fields: [
        SettingsFieldModel(
            path: 'reminders.default_minutes',
            label: 'Default reminder',
            description: 'Minutes before a task or event',
            type: 'number'),
        SettingsFieldModel(
            path: 'reminders.smart_reminders',
            label: 'Smart reminders',
            description: 'Use local context for suggestions',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'search',
      label: 'Search',
      icon: 'search',
      description: 'History, suggestions, semantic, OCR, and voice search',
      fields: [
        SettingsFieldModel(
            path: 'search.suggestions',
            label: 'Search suggestions',
            description: 'Show recent local suggestions',
            type: 'bool'),
        SettingsFieldModel(
            path: 'search.semantic',
            label: 'Semantic search',
            description: 'Use local embeddings when available',
            type: 'bool'),
        SettingsFieldModel(
            path: 'search.ocr',
            label: 'OCR search',
            description: 'Include indexed image text',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'voice',
      label: 'Voice',
      icon: 'mic',
      description: 'Offline speech recognition and microphone behavior',
      fields: [
        SettingsFieldModel(
            path: 'voice.whisper_model',
            label: 'Whisper model',
            description: 'Local model size',
            type: 'select',
            options: ['tiny', 'base', 'small']),
        SettingsFieldModel(
            path: 'voice.offline_recognition',
            label: 'Offline recognition',
            description: 'Prefer local recognition',
            type: 'bool'),
        SettingsFieldModel(
            path: 'voice.microphone',
            label: 'Microphone',
            description: 'Allow microphone access',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'security',
      label: 'Security',
      icon: 'security',
      description: 'PIN, session, secure storage, and encryption controls',
      fields: [
        SettingsFieldModel(
            path: 'security.pin_lock',
            label: 'PIN lock',
            description: 'Lock the local app with a PIN',
            type: 'bool'),
        SettingsFieldModel(
            path: 'security.auto_lock_minutes',
            label: 'Auto-lock minutes',
            description: 'Zero disables auto-lock',
            type: 'number'),
        SettingsFieldModel(
            path: 'security.encryption',
            label: 'Encryption',
            description: 'Use secure local storage where available',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'privacy',
      label: 'Privacy',
      icon: 'privacy',
      description: 'Telemetry, AI memory, search, cache, and local data',
      fields: [
        SettingsFieldModel(
            path: 'privacy.analytics_enabled',
            label: 'Share analytics',
            description: 'Off by default',
            type: 'bool'),
        SettingsFieldModel(
            path: 'privacy.ai_memory_enabled',
            label: 'AI memory',
            description: 'Allow local assistant memory',
            type: 'bool'),
        SettingsFieldModel(
            path: 'privacy.telemetry',
            label: 'Telemetry',
            description: 'No telemetry by default',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'backup',
      label: 'Backup',
      icon: 'backup',
      description: 'Verified local settings snapshots and restore',
      fields: [
        SettingsFieldModel(
            path: 'backup.scheduled',
            label: 'Scheduled backup',
            description: 'Evaluate while the app is active or resumes',
            type: 'bool'),
        SettingsFieldModel(
            path: 'backup.schedule',
            label: 'Backup schedule',
            description: 'Stored local schedule metadata',
            type: 'select',
            options: ['daily', 'weekly', 'monthly'])
      ]),
  SettingsCategoryModel(
      id: 'storage',
      label: 'Storage',
      icon: 'storage',
      description: 'Database, cache, model, and cleanup information',
      fields: [
        SettingsFieldModel(
            path: 'storage.cache_cleanup_days',
            label: 'Cache cleanup days',
            description: 'Retention target',
            type: 'number'),
        SettingsFieldModel(
            path: 'storage.temporary_cleanup',
            label: 'Temporary cleanup',
            description: 'Clean temporary files locally',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'accessibility',
      label: 'Accessibility',
      icon: 'accessibility',
      description:
          'Text, contrast, motion, screen reader, and keyboard support',
      fields: [
        SettingsFieldModel(
            path: 'accessibility.large_text',
            label: 'Large text',
            description: 'Increase text scale',
            type: 'bool'),
        SettingsFieldModel(
            path: 'accessibility.high_contrast',
            label: 'High contrast',
            description: 'Use stronger surface contrast',
            type: 'bool'),
        SettingsFieldModel(
            path: 'accessibility.reduced_motion',
            label: 'Reduced motion',
            description: 'Avoid nonessential animation',
            type: 'bool'),
        SettingsFieldModel(
            path: 'accessibility.keyboard_navigation',
            label: 'Keyboard navigation',
            description: 'Keep keyboard focus paths visible',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'language',
      label: 'Language',
      icon: 'language',
      description: 'Locale and region formatting',
      fields: [
        SettingsFieldModel(
            path: 'language.locale',
            label: 'Language',
            description: 'Current language',
            type: 'select',
            options: ['en']),
        SettingsFieldModel(
            path: 'language.region',
            label: 'Region',
            description: 'Region formats',
            type: 'select',
            options: ['US', 'IN', 'GB'])
      ]),
  SettingsCategoryModel(
      id: 'integrations',
      label: 'Integrations',
      icon: 'integration',
      description: 'Local AI, plugins, import/export, and future sync',
      fields: [
        SettingsFieldModel(
            path: 'integrations.local_ai',
            label: 'Local AI',
            description: 'Use local model adapters',
            type: 'bool'),
        SettingsFieldModel(
            path: 'integrations.plugin_system',
            label: 'Plugin system',
            description: 'Future plugin surface',
            type: 'bool'),
        SettingsFieldModel(
            path: 'integrations.future_cloud_sync',
            label: 'Future cloud sync',
            description: 'Disabled until explicitly configured',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'developer',
      label: 'Developer',
      icon: 'developer',
      description: 'Local debug logs, flags, performance, and sync state',
      fields: [
        SettingsFieldModel(
            path: 'developer.debug_logs',
            label: 'Debug logs',
            description: 'Show local diagnostics',
            type: 'bool'),
        SettingsFieldModel(
            path: 'developer.performance_metrics',
            label: 'Performance metrics',
            description: 'Collect local timing only',
            type: 'bool')
      ]),
  SettingsCategoryModel(
      id: 'about',
      label: 'About',
      icon: 'info',
      description: 'Version, licenses, privacy, and credits',
      fields: []),
];
