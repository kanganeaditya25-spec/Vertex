import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/notes/note_models.dart';

class NotesRepository {
  NotesRepository(this._preferences);

  final SharedPreferences _preferences;
  static const _notesKey = 'module5_notes_v1';
  static const _queueKey = 'module5_notes_sync_queue_v1';

  Future<List<NoteModel>> loadNotes() async {
    final encoded = _preferences.getString(_notesKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(NoteModel.fromJson)
          .where((note) => !note.deleted)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<NoteModel> create(NoteModel note) async {
    final saved = note.copyWith(
        syncStatus: 'pending',
        version: note.version + 1,
        updatedAt: DateTime.now());
    await _save([...await loadNotes(), saved]);
    await _queue(saved, 'create');
    return saved;
  }

  Future<NoteModel> update(NoteModel note) async {
    final saved = note.copyWith(
        syncStatus: 'pending',
        version: note.version + 1,
        updatedAt: DateTime.now());
    await _save((await loadNotes())
        .map((item) => item.id == saved.id ? saved : item)
        .toList());
    await _queue(saved, 'update');
    return saved;
  }

  Future<void> remove(NoteModel note) async {
    final deleted = note.copyWith(
        deleted: true,
        syncStatus: 'pending',
        version: note.version + 1,
        updatedAt: DateTime.now());
    await _save((await loadNotes())
        .map((item) => item.id == note.id ? deleted : item)
        .toList());
    await _queue(deleted, 'delete');
  }

  Future<List<NoteModel>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return loadNotes();
    return (await loadNotes())
        .where((note) =>
            '${note.title} ${note.summary} ${note.tags.join(' ')} ${note.blocks.map((block) => block.content).join(' ')}'
                .toLowerCase()
                .contains(normalized))
        .toList();
  }

  Future<NoteModel?> link(NoteModel source, NoteModel target) async {
    if (source.id == target.id) return null;
    final savedSource = source.copyWith(
        outgoingNoteIds: {...source.outgoingNoteIds, target.id}.toList());
    final savedTarget = target.copyWith(
        incomingNoteIds: {...target.incomingNoteIds, source.id}.toList());
    final notes = await loadNotes();
    await _save(notes
        .map((note) => note.id == source.id
            ? savedSource
            : note.id == target.id
                ? savedTarget
                : note)
        .toList());
    await _queue(savedSource, 'link');
    return savedSource;
  }

  Future<void> _save(List<NoteModel> notes) async => _preferences.setString(
      _notesKey, jsonEncode(notes.map((note) => note.toJson()).toList()));

  Future<void> _queue(NoteModel note, String operation) async {
    final encoded = _preferences.getString(_queueKey);
    final queue = encoded == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(encoded) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList();
    queue.add({
      'id': '${note.id}:$operation:${note.version}',
      'noteId': note.id,
      'operation': operation,
      'version': note.version,
      'createdAt': DateTime.now().toIso8601String(),
      'payload': note.toJson()
    });
    await _preferences.setString(_queueKey, jsonEncode(queue));
  }
}
