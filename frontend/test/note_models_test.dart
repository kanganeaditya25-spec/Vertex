import 'package:flutter_test/flutter_test.dart';

import 'package:productivity_dashboard/features/notes/note_models.dart';

void main() {
  test('note blocks round-trip and checklist progress is accurate', () {
    const note = NoteModel(
      id: 'note-1',
      title: 'Second brain',
      blocks: [
        NoteBlock(id: 'b1', blockType: 'heading1', content: 'Knowledge'),
        NoteBlock(
            id: 'b2',
            blockType: 'checklist',
            content: 'Review links',
            checked: true,
            position: 1),
        NoteBlock(
            id: 'b3',
            blockType: 'checklist',
            content: 'Add summary',
            position: 2),
      ],
      tags: ['knowledge'],
      wordCount: 4,
    );
    final decoded = NoteModel.fromJson(note.toJson());

    expect(decoded.title, 'Second brain');
    expect(decoded.blocks.length, 3);
    expect(decoded.checklistCount, 2);
    expect(decoded.completedChecklistCount, 1);
    expect(decoded.checklistProgress, 0.5);
    expect(decoded.tags, ['knowledge']);
  });

  test('note copy preserves links and can toggle knowledge metadata', () {
    const note = NoteModel(
        id: 'note-1',
        title: 'Source',
        outgoingNoteIds: ['note-2'],
        incomingNoteIds: ['note-3'],
        pinned: true);
    final updated =
        note.copyWith(favorite: true, knowledgeScore: 82, version: 2);

    expect(updated.pinned, isTrue);
    expect(updated.favorite, isTrue);
    expect(updated.knowledgeScore, 82);
    expect(updated.outgoingNoteIds, ['note-2']);
    expect(updated.incomingNoteIds, ['note-3']);
  });
}
