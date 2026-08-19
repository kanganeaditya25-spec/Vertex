import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'note_models.dart';
import 'notes_providers.dart';

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key, this.projectId});
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Brain'),
        actions: [
          IconButton(
              tooltip: 'New note',
              onPressed: () => ref
                  .read(notesControllerProvider.notifier)
                  .createNote(projectId: projectId),
              icon: const Icon(Icons.note_add_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              ref.read(notesControllerProvider.notifier).createNote(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New note')),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _NotesError(
            message: error.toString(),
            retry: () => ref.invalidate(notesControllerProvider)),
        data: (state) => _NotesWorkspace(state: state, projectId: projectId),
      ),
    );
  }
}

class _NotesWorkspace extends ConsumerWidget {
  const _NotesWorkspace({required this.state, this.projectId});
  final NotesState state;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final list = _NoteList(state: state, projectId: projectId);
    final selectedNote = state.selectedNoteFor(projectId);
    final editor = selectedNote == null
        ? _EmptyNotesEditor(
            onCreate: () => ref
                .read(notesControllerProvider.notifier)
                .createNote(projectId: projectId))
        : _NoteEditor(note: selectedNote);
    if (wide) {
      return Row(children: [
        SizedBox(width: 330, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: editor)
      ]);
    }
    return Column(children: [
      SizedBox(height: 285, child: list),
      const Divider(height: 1),
      Expanded(child: editor)
    ]);
  }
}

class _NoteList extends ConsumerWidget {
  const _NoteList({required this.state, this.projectId});
  final NotesState state;
  final String? projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notesControllerProvider.notifier);
    final visibleNotes = state.visibleNotesFor(projectId);
    return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(children: [
          TextField(
              onChanged: controller.setQuery,
              decoration: InputDecoration(
                  hintText: 'Search notes and tags…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: state.query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => controller.setQuery(''),
                          icon: const Icon(Icons.clear_rounded)),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none))),
          const SizedBox(height: 8),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                FilterChip(
                    label: const Text('All'),
                    selected:
                        !state.favoriteOnly && state.noteTypeFilter == null,
                    onSelected: (_) {
                      controller.setFavoriteOnly(false);
                      controller.setTypeFilter(null);
                    }),
                FilterChip(
                    label: const Text('Favorites'),
                    selected: state.favoriteOnly,
                    onSelected: controller.setFavoriteOnly),
                const SizedBox(width: 6),
                ...['meeting', 'research', 'journal', 'idea'].map((type) =>
                    Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FilterChip(
                            label: Text(type),
                            selected: state.noteTypeFilter == type,
                            onSelected: (_) => controller.setTypeFilter(
                                state.noteTypeFilter == type ? null : type))))
              ])),
          const SizedBox(height: 8),
          Expanded(
              child: visibleNotes.isEmpty
                  ? const Center(child: Text('No notes match this view.'))
                  : ListView.builder(
                      itemCount: visibleNotes.length,
                      itemBuilder: (context, index) {
                        final note = visibleNotes[index];
                        return _NoteListTile(
                            note: note, selected: note.id == state.selectedId);
                      })),
        ]));
  }
}

class _NoteListTile extends ConsumerWidget {
  const _NoteListTile({required this.note, required this.selected});
  final NoteModel note;
  final bool selected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notesControllerProvider.notifier);
    final color =
        selected ? Theme.of(context).colorScheme.secondaryContainer : null;
    return Card(
        color: color,
        elevation: selected ? 1 : 0,
        child: ListTile(
            onTap: () => controller.selectNote(note.id),
            leading: Icon(note.pinned
                ? Icons.push_pin_rounded
                : Icons.description_outlined),
            title: Text(note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                note.blocks
                    .map((block) => block.content)
                    .where((text) => text.isNotEmpty)
                    .join(' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            trailing: note.favorite
                ? const Icon(Icons.star_rounded, color: Colors.amber)
                : Text('${note.wordCount}w',
                    style: Theme.of(context).textTheme.labelSmall)));
  }
}

class _NoteEditor extends ConsumerStatefulWidget {
  const _NoteEditor({required this.note});
  final NoteModel note;
  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late TextEditingController _titleController;
  Timer? _saveTimer;
  String _saveStatus = 'Saved locally';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
  }

  @override
  void didUpdateWidget(covariant _NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      _titleController.text = widget.note.title;
      _saveStatus = 'Saved locally';
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _scheduleTitleSave() {
    _saveTimer?.cancel();
    setState(() => _saveStatus = 'Saving locally…');
    _saveTimer = Timer(const Duration(milliseconds: 550), () async {
      await ref
          .read(notesControllerProvider.notifier)
          .updateNote(widget.note.copyWith(title: _titleController.text));
      if (mounted) setState(() => _saveStatus = 'Saved locally');
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(notesControllerProvider.notifier);
    final note = widget.note;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _titleController,
                    onChanged: (_) => _scheduleTitleSave(),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(
                        hintText: 'Untitled note', border: InputBorder.none))),
            IconButton(
                tooltip: 'Favorite',
                onPressed: () => controller.toggleFavorite(note),
                icon: Icon(
                    note.favorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: note.favorite ? Colors.amber : null)),
            IconButton(
                tooltip: 'Pin',
                onPressed: () => controller.togglePinned(note),
                icon: Icon(note.pinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined)),
            PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    controller.deleteNote(note);
                  }
                  if (value == 'archive') {
                    controller.updateNote(note.copyWith(archived: true));
                  }
                },
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 'archive', child: Text('Archive')),
                      PopupMenuItem(
                          value: 'delete', child: Text('Move to trash'))
                    ])
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _MetaChip(icon: Icons.category_outlined, label: note.noteType),
            _MetaChip(
                icon: Icons.label_outline_rounded,
                label: note.tags.isEmpty ? 'No tags' : note.tags.join(', ')),
            _MetaChip(
                icon: Icons.schedule_rounded,
                label: '${note.readingTimeMinutes} min read'),
            _MetaChip(icon: Icons.history_rounded, label: 'v${note.version}'),
            _MetaChip(icon: Icons.cloud_off_rounded, label: _saveStatus)
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Text('Blocks',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            PopupMenuButton<String>(
                tooltip: 'Insert block',
                onSelected: (type) => controller.addBlock(note, type),
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'paragraph', child: Text('Paragraph')),
                      PopupMenuItem(
                          value: 'heading1', child: Text('Heading 1')),
                      PopupMenuItem(
                          value: 'heading2', child: Text('Heading 2')),
                      PopupMenuItem(
                          value: 'checklist', child: Text('Checklist')),
                      PopupMenuItem(value: 'quote', child: Text('Quote')),
                      PopupMenuItem(value: 'callout', child: Text('Callout')),
                      PopupMenuItem(value: 'code', child: Text('Code')),
                      PopupMenuItem(value: 'divider', child: Text('Divider'))
                    ],
                child: const Icon(Icons.add_circle_outline_rounded))
          ]),
          const SizedBox(height: 8),
          if (note.blocks.isEmpty)
            _EmptyBlock(onAdd: () => controller.addBlock(note, 'paragraph'))
          else
            ...note.blocks
                .map((block) => _BlockEditor(note: note, block: block)),
          const SizedBox(height: 18),
          _NoteStats(note: note),
          if (note.hasLinks) ...[
            const SizedBox(height: 18),
            _LinkPanel(note: note)
          ],
        ]);
  }
}

class _BlockEditor extends ConsumerStatefulWidget {
  const _BlockEditor({required this.note, required this.block});
  final NoteModel note;
  final NoteBlock block;
  @override
  ConsumerState<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<_BlockEditor> {
  late TextEditingController _controller;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block.content);
  }

  @override
  void didUpdateWidget(covariant _BlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.block.content != widget.block.content) {
      _controller.text = widget.block.content;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _save(String value) {
    _timer?.cancel();
    _timer = Timer(
        const Duration(milliseconds: 500),
        () => ref
            .read(notesControllerProvider.notifier)
            .updateBlock(widget.note, widget.block.copyWith(content: value)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(notesControllerProvider.notifier);
    final block = widget.block;
    if (block.blockType == 'divider') {
      return Row(children: [
        const Expanded(child: Divider(thickness: 2)),
        IconButton(
            tooltip: 'Delete block',
            onPressed: () => controller.deleteBlock(widget.note, block),
            icon: const Icon(Icons.close_rounded, size: 18))
      ]);
    }
    final style = block.blockType.startsWith('heading')
        ? Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700)
        : null;
    return Card(
        elevation: 0,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (block.blockType == 'checklist')
                Checkbox(
                    value: block.checked,
                    onChanged: (_) =>
                        controller.toggleChecklist(widget.note, block)),
              Expanded(
                  child: TextField(
                      controller: _controller,
                      onChanged: _save,
                      maxLines: null,
                      minLines: block.blockType == 'paragraph' ? 2 : 1,
                      style: style,
                      decoration: InputDecoration(
                          labelText: _blockLabel(block.blockType),
                          border: InputBorder.none,
                          hintText: _blockHint(block.blockType)))),
              PopupMenuButton<String>(
                  tooltip: 'Block actions',
                  onSelected: (value) {
                    if (value == 'delete') {
                      controller.deleteBlock(widget.note, block);
                    }
                    if (value == 'duplicate') {
                      controller.addBlock(widget.note, block.blockType);
                    }
                  },
                  itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'duplicate', child: Text('Duplicate')),
                        PopupMenuItem(value: 'delete', child: Text('Delete'))
                      ])
            ])));
  }
}

class _NoteStats extends StatelessWidget {
  const _NoteStats({required this.note});
  final NoteModel note;
  @override
  Widget build(BuildContext context) => Card(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.45),
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(spacing: 18, runSpacing: 8, children: [
            Text('${note.wordCount} words'),
            Text('${note.blocks.length} blocks'),
            Text(
                '${note.checklistCount == 0 ? 0 : (note.checklistProgress * 100).round()}% checklist'),
            Text('Knowledge ${note.knowledgeScore.round()}')
          ])));
}

class _LinkPanel extends StatelessWidget {
  const _LinkPanel({required this.note});
  final NoteModel note;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Knowledge links',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (note.incomingNoteIds.isNotEmpty)
              Text('Backlinks: ${note.incomingNoteIds.length}'),
            if (note.outgoingNoteIds.isNotEmpty)
              Text('Outgoing links: ${note.outgoingNoteIds.length}'),
            const SizedBox(height: 4),
            Text(
                'Links are stored locally and remain ready for the Knowledge Graph.',
                style: Theme.of(context).textTheme.bodySmall)
          ])));
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none);
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Icon(Icons.edit_note_rounded, size: 48),
              const SizedBox(height: 8),
              const Text(
                  'Start with a paragraph or insert a structured block.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add paragraph')),
            ],
          ),
        ),
      );
}

class _EmptyNotesEditor extends StatelessWidget {
  const _EmptyNotesEditor({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.psychology_alt_rounded, size: 64),
              const SizedBox(height: 12),
              Text('Your second brain starts here',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                  'Capture an idea, connect it to work, and keep it available offline.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.note_add_rounded),
                  label: const Text('Create your first note')),
            ],
          ),
        ),
      );
}

class _NotesError extends StatelessWidget {
  const _NotesError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.menu_book_rounded, size: 48),
            const SizedBox(height: 12),
            const Text('Notes could not be loaded'),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: retry, child: const Text('Retry'))
          ])));
}

String _blockLabel(String type) => switch (type) {
      'heading1' => 'Heading 1',
      'heading2' => 'Heading 2',
      'checklist' => 'Checklist item',
      'quote' => 'Quote',
      'callout' => 'Callout',
      'code' => 'Code',
      _ => 'Paragraph'
    };
String _blockHint(String type) => switch (type) {
      'checklist' => 'What needs to be done?',
      'quote' => 'A thought worth keeping…',
      'code' => 'Paste code here…',
      'callout' => 'Important context…',
      _ => 'Write something useful…'
    };
