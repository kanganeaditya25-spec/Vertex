import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/notes_repository.dart';
import 'note_models.dart';

final notesControllerProvider =
    AsyncNotifierProvider<NotesController, NotesState>(NotesController.new);

class NotesState {
  const NotesState(
      {required this.notes,
      this.selectedId,
      this.query = '',
      this.favoriteOnly = false,
      this.noteTypeFilter});
  final List<NoteModel> notes;
  final String? selectedId;
  final String query;
  final bool favoriteOnly;
  final String? noteTypeFilter;

  NoteModel? get selectedNote =>
      notes.where((note) => note.id == selectedId).firstOrNull;
  List<NoteModel> get visibleNotes => visibleNotesFor(null);

  NoteModel? selectedNoteFor(String? projectId) => notes
      .where((note) =>
          note.id == selectedId &&
          (projectId == null || note.projectId == projectId))
      .firstOrNull;

  List<NoteModel> visibleNotesFor(String? projectId) {
    final normalized = query.trim().toLowerCase();
    final result = notes.where((note) {
      final searchText =
          '${note.title} ${note.summary} ${note.tags.join(' ')} ${note.blocks.map((block) => block.content).join(' ')}'
              .toLowerCase();
      return (normalized.isEmpty || searchText.contains(normalized)) &&
          (!favoriteOnly || note.favorite) &&
          (noteTypeFilter == null || note.noteType == noteTypeFilter) &&
          (projectId == null || note.projectId == projectId);
    }).toList();
    result.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return (b.updatedAt ?? DateTime(1970))
          .compareTo(a.updatedAt ?? DateTime(1970));
    });
    return result;
  }

  NotesState copyWith(
          {List<NoteModel>? notes,
          String? selectedId,
          String? query,
          bool? favoriteOnly,
          String? noteTypeFilter,
          bool clearFilter = false}) =>
      NotesState(
          notes: notes ?? this.notes,
          selectedId: selectedId ?? this.selectedId,
          query: query ?? this.query,
          favoriteOnly: favoriteOnly ?? this.favoriteOnly,
          noteTypeFilter:
              clearFilter ? null : noteTypeFilter ?? this.noteTypeFilter);
}

class NotesController extends AsyncNotifier<NotesState> {
  NotesRepository? _repository;

  @override
  Future<NotesState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = NotesRepository(preferences);
    final notes = await _repository!.loadNotes();
    return NotesState(
        notes: notes, selectedId: notes.isEmpty ? null : notes.first.id);
  }

  Future<void> selectNote(String? id) async =>
      _setState((current) => current.copyWith(selectedId: id));
  Future<void> setQuery(String query) async =>
      _setState((current) => current.copyWith(query: query));
  Future<void> setFavoriteOnly(bool value) async =>
      _setState((current) => current.copyWith(favoriteOnly: value));
  Future<void> setTypeFilter(String? value) async =>
      _setState((current) => value == null
          ? current.copyWith(clearFilter: true)
          : current.copyWith(noteTypeFilter: value));

  Future<void> createNote(
      {String title = 'Untitled note',
      String noteType = 'rich',
      String? projectId}) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    final now = DateTime.now();
    final note = NoteModel(
        id: 'local-${now.microsecondsSinceEpoch}',
        title: title,
        noteType: noteType,
        projectId: projectId,
        blocks: [
          NoteBlock(
              id: 'block-${now.microsecondsSinceEpoch}',
              blockType: 'paragraph',
              content: '',
              position: 0)
        ],
        createdAt: now,
        updatedAt: now);
    final saved = await _repository!.create(note);
    state = AsyncData(current
        .copyWith(notes: [saved, ...current.notes], selectedId: saved.id));
  }

  Future<void> updateNote(NoteModel note) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null || note.archived) return;
    final saved = await _repository!.update(note);
    state = AsyncData(current.copyWith(
        notes: current.notes
            .map((item) => item.id == saved.id ? saved : item)
            .toList(),
        selectedId: saved.id));
  }

  Future<void> deleteNote(NoteModel note) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    await _repository!.remove(note);
    final remaining =
        current.notes.where((item) => item.id != note.id).toList();
    state = AsyncData(current.copyWith(
        notes: remaining, selectedId: remaining.firstOrNull?.id));
  }

  Future<void> toggleFavorite(NoteModel note) async =>
      updateNote(note.copyWith(favorite: !note.favorite));
  Future<void> togglePinned(NoteModel note) async =>
      updateNote(note.copyWith(pinned: !note.pinned));

  Future<void> addBlock(NoteModel note, String blockType) async {
    final block = NoteBlock(
        id: 'block-${DateTime.now().microsecondsSinceEpoch}',
        blockType: blockType,
        content: '',
        position: note.blocks.length);
    await updateNote(note.copyWith(blocks: [...note.blocks, block]));
  }

  Future<void> updateBlock(NoteModel note, NoteBlock block) async =>
      updateNote(note.copyWith(
          blocks: note.blocks
              .map((item) => item.id == block.id ? block : item)
              .toList()));

  Future<void> deleteBlock(NoteModel note, NoteBlock block) async {
    final blocks = note.blocks
        .where((item) => item.id != block.id)
        .toList()
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(position: entry.key))
        .toList();
    await updateNote(note.copyWith(blocks: blocks));
  }

  Future<void> toggleChecklist(NoteModel note, NoteBlock block) async =>
      updateBlock(note, block.copyWith(checked: !block.checked));

  Future<void> linkNotes(NoteModel source, NoteModel target) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null || source.id == target.id) {
      return;
    }
    await _repository!.link(source, target);
    final updatedSource = source.copyWith(
        outgoingNoteIds: {...source.outgoingNoteIds, target.id}.toList());
    final updatedTarget = target.copyWith(
        incomingNoteIds: {...target.incomingNoteIds, source.id}.toList());
    state = AsyncData(current.copyWith(
        notes: current.notes
            .map((note) => note.id == source.id
                ? updatedSource
                : note.id == target.id
                    ? updatedTarget
                    : note)
            .toList()));
  }

  Future<void> _setState(NotesState Function(NotesState) update) async {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(update(current));
  }
}
