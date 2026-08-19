import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'asset_models.dart';
import 'asset_providers.dart';

class AssetsPage extends ConsumerWidget {
  const AssetsPage({super.key, this.projectId});
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(assetControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Library'),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: () =>
                  ref.read(assetControllerProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded)),
          IconButton(
              tooltip: 'Import files',
              onPressed: () => _importFiles(context, ref, projectId: projectId),
              icon: const Icon(Icons.file_upload_outlined)),
          IconButton(
              tooltip: 'Save URL',
              onPressed: () =>
                  _showUrlDialog(context, ref, projectId: projectId),
              icon: const Icon(Icons.link_rounded)),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Asset Library could not load: $error')),
        data: (state) => _AssetWorkspace(state: state, projectId: projectId),
      ),
    );
  }
}

class _AssetWorkspace extends ConsumerWidget {
  const _AssetWorkspace({required this.state, this.projectId});
  final AssetState state;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopedState = state.forProject(projectId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebar = _LibrarySidebar(state: scopedState);
        final content = _AssetContent(state: scopedState, projectId: projectId);
        if (constraints.maxWidth < 860) {
          return Column(children: [
            SizedBox(height: 138, child: sidebar),
            Expanded(child: content)
          ]);
        }
        return Row(children: [
          SizedBox(width: 236, child: sidebar),
          Expanded(child: content)
        ]);
      },
    );
  }
}

class _LibrarySidebar extends ConsumerWidget {
  const _LibrarySidebar({required this.state});
  final AssetState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(assetControllerProvider.notifier);
    final categories = <String, int>{};
    for (final asset in state.assets.where((asset) => !asset.trashed)) {
      categories[asset.assetType] = (categories[asset.assetType] ?? 0) + 1;
    }
    final items = <({String id, String label, IconData icon, int count})>[
      (
        id: 'all',
        label: 'All assets',
        icon: Icons.folder_copy_outlined,
        count: state.assets.where((asset) => !asset.trashed).length
      ),
      (
        id: 'favorite',
        label: 'Favorites',
        icon: Icons.star_border_rounded,
        count: state.assets
            .where((asset) => asset.favorite && !asset.trashed)
            .length
      ),
      (
        id: 'recent',
        label: 'Recent',
        icon: Icons.schedule_rounded,
        count: state.assets.where((asset) => !asset.trashed).length
      ),
      (
        id: 'archive',
        label: 'Archive',
        icon: Icons.archive_outlined,
        count: state.assets.where((asset) => asset.archived).length
      ),
      (
        id: 'trash',
        label: 'Trash',
        icon: Icons.delete_outline_rounded,
        count: state.assets.where((asset) => asset.trashed).length
      ),
    ];
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 0,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        scrollDirection: Axis.vertical,
        children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Text('Library',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          for (final item in items)
            ListTile(
              dense: true,
              selected: state.selectedFolder == item.id,
              leading: Icon(item.icon),
              title: Text(item.label),
              trailing: Text('${item.count}'),
              onTap: () =>
                  controller.setFolder(item.id == 'all' ? 'all' : item.id),
            ),
          const Divider(height: 20),
          const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Text('Folders',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          for (final folder in state.folders)
            ListTile(
                dense: true,
                selected: state.selectedFolder == folder.id,
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
                onTap: () => controller.setFolder(folder.id)),
          ListTile(
              dense: true,
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder'),
              onTap: () => _showFolderDialog(context, ref)),
          const Divider(height: 20),
          const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 4),
              child:
                  Text('Types', style: TextStyle(fontWeight: FontWeight.w800))),
          for (final entry in categories.entries)
            ListTile(
                dense: true,
                selected: state.selectedType == entry.key,
                leading: Icon(_iconForType(entry.key)),
                title: Text(entry.key.toUpperCase()),
                trailing: Text('${entry.value}'),
                onTap: () => controller.setType(entry.key)),
        ],
      ),
    );
  }
}

class _AssetContent extends ConsumerWidget {
  const _AssetContent({required this.state, this.projectId});
  final AssetState state;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(assetControllerProvider.notifier);
    final assets = state.visibleAssets;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _StatsStrip(stats: state.stats),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: TextField(
                  onChanged: controller.setQuery,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search files, OCR text, tags, and metadata',
                      border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'grid', icon: Icon(Icons.grid_view_rounded)),
                ButtonSegment(
                    value: 'list', icon: Icon(Icons.view_list_rounded))
              ],
              selected: {
                state.viewMode
              },
              onSelectionChanged: (value) =>
                  controller.setViewMode(value.first)),
        ]),
        if (state.selectedIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
              elevation: 0,
              color: const Color(0xFFE0E7FF),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(children: [
                    Text('${state.selectedIds.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                        onPressed: () => controller.bulkAction('favorite'),
                        child: const Text('Favorite')),
                    TextButton(
                        onPressed: () => controller.bulkAction('archive'),
                        child: const Text('Archive')),
                    TextButton(
                        onPressed: () => controller.bulkAction('delete'),
                        child: const Text('Delete')),
                    TextButton(
                        onPressed: controller.clearSelection,
                        child: const Text('Clear'))
                  ]))),
        ],
        const SizedBox(height: 10),
        Expanded(
            child: assets.isEmpty
                ? _EmptyLibrary(
                    onImport: () =>
                        _importFiles(context, ref, projectId: projectId),
                    onUrl: () =>
                        _showUrlDialog(context, ref, projectId: projectId))
                : state.viewMode == 'grid'
                    ? _AssetGrid(assets: assets)
                    : _AssetList(assets: assets)),
      ]),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});
  final AssetStatsModel stats;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 72,
      child: Row(children: [
        Expanded(
            child: _Metric(
                label: 'Assets',
                value: '${stats.fileCount}',
                icon: Icons.folder_copy_outlined)),
        Expanded(
            child: _Metric(
                label: 'Storage',
                value: _formatBytes(stats.totalStorageBytes),
                icon: Icons.storage_outlined)),
        Expanded(
            child: _Metric(
                label: 'Favorites',
                value: '${stats.favoriteCount}',
                icon: Icons.star_border_rounded)),
        Expanded(
            child: _Metric(
                label: 'Duplicates',
                value: '${stats.duplicateGroups.length}',
                icon: Icons.content_copy_rounded))
      ]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      child: ListTile(
          dense: true,
          leading: Icon(icon, color: const Color(0xFF4F46E5)),
          title:
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(label)));
}

class _AssetGrid extends ConsumerWidget {
  const _AssetGrid({required this.assets});
  final List<AssetModel> assets;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisExtent: 212,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10),
      itemCount: assets.length,
      itemBuilder: (context, index) => _AssetCard(asset: assets[index]));
}

class _AssetCard extends ConsumerWidget {
  const _AssetCard({required this.asset});
  final AssetModel asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assetControllerProvider).valueOrNull;
    final selected = state?.selectedIds.contains(asset.id) ?? false;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showPreview(context, ref, asset),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Checkbox(
                    value: selected,
                    onChanged: (_) => ref
                        .read(assetControllerProvider.notifier)
                        .toggleSelection(asset.id)),
                const Spacer(),
                if (asset.favorite)
                  const Icon(Icons.star_rounded,
                      size: 18, color: Color(0xFFB45309)),
                PopupMenuButton<String>(
                  tooltip: 'Asset actions',
                  onSelected: (action) async {
                    final controller =
                        ref.read(assetControllerProvider.notifier);
                    if (action == 'favorite') {
                      await controller.saveAsset(
                          asset.copyWith(favorite: !asset.favorite),
                          action: 'favorite');
                    } else if (action == 'pin') {
                      await controller.saveAsset(
                          asset.copyWith(pinned: !asset.pinned),
                          action: 'pin');
                    } else if (action == 'archive') {
                      await controller.saveAsset(
                          asset.copyWith(archived: !asset.archived),
                          action: 'archive');
                    } else if (action == 'delete') {
                      await controller.bulkActionFor([asset.id], 'delete');
                    } else if (action == 'restore') {
                      await controller.bulkActionFor([asset.id], 'restore');
                    } else if (action == 'duplicate') {
                      await controller.duplicateAsset(asset.id);
                    } else if (action == 'copy') {
                      await Clipboard.setData(
                          ClipboardData(text: prettyJson(asset.toJson())));
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: 'favorite',
                        child: Text(
                            asset.favorite ? 'Remove favorite' : 'Favorite')),
                    PopupMenuItem(
                        value: 'pin',
                        child: Text(asset.pinned ? 'Unpin' : 'Pin')),
                    PopupMenuItem(
                        value: 'archive',
                        child: Text(asset.archived
                            ? 'Restore from archive'
                            : 'Archive')),
                    if (asset.trashed)
                      const PopupMenuItem(
                          value: 'restore', child: Text('Restore from trash')),
                    if (!asset.trashed)
                      const PopupMenuItem(
                          value: 'delete', child: Text('Move to trash')),
                    const PopupMenuItem(
                        value: 'duplicate', child: Text('Duplicate metadata')),
                    const PopupMenuItem(
                        value: 'copy', child: Text('Copy metadata JSON')),
                  ],
                ),
              ]),
              Expanded(
                  child: Center(
                      child: Icon(_iconForType(asset.assetType),
                          size: 46, color: const Color(0xFF4F46E5)))),
              Text(asset.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  '${asset.extensionLabel} · ${_formatBytes(asset.sizeBytes)} · ${asset.offlineContent ? 'offline' : asset.isUrl ? 'URL' : 'metadata'}',
                  style: Theme.of(context).textTheme.bodySmall),
            ])),
      ),
    );
  }
}

class _AssetList extends ConsumerWidget {
  const _AssetList({required this.assets});
  final List<AssetModel> assets;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView.separated(
      itemCount: assets.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final asset = assets[index];
        final selected = ref
                .watch(assetControllerProvider)
                .valueOrNull
                ?.selectedIds
                .contains(asset.id) ??
            false;
        return ListTile(
            leading: Checkbox(
                value: selected,
                onChanged: (_) => ref
                    .read(assetControllerProvider.notifier)
                    .toggleSelection(asset.id)),
            title: Text(asset.name),
            subtitle: Text(
                '${asset.assetType} · ${asset.extensionLabel} · ${_formatBytes(asset.sizeBytes)} · ${asset.tags.join(', ')}'),
            trailing: Icon(_iconForType(asset.assetType)),
            onTap: () => _showPreview(context, ref, asset));
      });
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport, required this.onUrl});
  final VoidCallback onImport;
  final VoidCallback onUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open_rounded,
                  size: 56, color: Color(0xFF4F46E5)),
              const SizedBox(height: 12),
              const Text('Your library is ready',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                  'Import a local file or save a URL. Assets are indexed locally by hash and metadata.'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                      onPressed: onImport,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Import files')),
                  OutlinedButton.icon(
                      onPressed: onUrl,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Save URL')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _importFiles(BuildContext context, WidgetRef ref,
    {String? projectId}) async {
  final result = await FilePicker.platform
      .pickFiles(allowMultiple: true, withData: true, type: FileType.any);
  if (result == null || !context.mounted) return;
  final count = await ref
      .read(assetControllerProvider.notifier)
      .importFiles(result, projectId: projectId ?? '');
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '$count asset${count == 1 ? '' : 's'} imported locally. Duplicate hashes were skipped.'),
      ),
    );
  }
}

Future<void> _showUrlDialog(BuildContext context, WidgetRef ref,
    {String? projectId}) async {
  final nameController = TextEditingController();
  final urlController = TextEditingController();
  final descriptionController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Save URL resource'),
      content: Form(
        key: formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title'
                    : null,
              ),
              TextFormField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL'),
                validator: (value) =>
                    Uri.tryParse(value ?? '')?.hasScheme == true
                        ? null
                        : 'Enter a valid URL',
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() == true) {
              Navigator.pop(dialogContext, true);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await ref.read(assetControllerProvider.notifier).createUrl(
          name: nameController.text.trim(),
          url: urlController.text.trim(),
          description: descriptionController.text.trim(),
          projectId: projectId ?? '',
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('URL saved to the local Asset Library.')));
    }
  }
}

Future<void> _showFolderDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Create folder'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Folder name'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim().isNotEmpty),
            child: const Text('Create')),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await ref
        .read(assetControllerProvider.notifier)
        .createFolder(controller.text.trim());
  }
}

Future<void> _showPreview(
    BuildContext context, WidgetRef ref, AssetModel asset) async {
  if (asset.isUrl) {
    final uri = Uri.tryParse(asset.sourceUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }
  final content = asset.contentBase64.isEmpty
      ? asset.previewText
      : utf8.decode(base64Decode(asset.contentBase64), allowMalformed: true);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(children: [
        Icon(_iconForType(asset.assetType)),
        const SizedBox(width: 8),
        Expanded(child: Text(asset.name))
      ]),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${asset.assetType.toUpperCase()} · ${asset.extensionLabel} · ${_formatBytes(asset.sizeBytes)}'),
              const SizedBox(height: 12),
              if (asset.isImage && asset.contentBase64.isNotEmpty)
                Image.memory(base64Decode(asset.contentBase64),
                    fit: BoxFit.contain, height: 260)
              else if (asset.isText && content.isNotEmpty)
                SelectableText(content)
              else
                Text(asset.offlineContent
                    ? 'This file is stored locally and can be opened by the system file viewer when an exported copy is available.'
                    : 'Only metadata is stored for this file because it exceeds the offline browser retention limit.'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Clipboard.setData(
                ClipboardData(text: prettyJson(asset.toJson()))),
            child: const Text('Copy metadata')),
        FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close')),
      ],
    ),
  );
}

IconData _iconForType(String type) => switch (type) {
      'image' => Icons.image_outlined,
      'audio' => Icons.audiotrack_outlined,
      'video' => Icons.movie_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'text' => Icons.article_outlined,
      'code' => Icons.code_rounded,
      'url' => Icons.link_rounded,
      'document' => Icons.description_outlined,
      _ => Icons.insert_drive_file_outlined
    };
String _formatBytes(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
        ? '${(bytes / 1024).toStringAsFixed(1)} KB'
        : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
