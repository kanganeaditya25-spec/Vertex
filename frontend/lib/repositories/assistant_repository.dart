import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/assistant/assistant_models.dart';

class AssistantRepository {
  AssistantRepository(this._preferences);
  final SharedPreferences _preferences;
  static const _conversationsKey = 'module6_assistant_conversations_v1';
  static const _memoriesKey = 'module6_assistant_memories_v1';

  Future<List<AssistantConversation>> loadConversations() async {
    final encoded = _preferences.getString(_conversationsKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(AssistantConversation.fromJson)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<List<AssistantMemory>> loadMemories() async {
    final encoded = _preferences.getString(_memoriesKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(AssistantMemory.fromJson)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<AssistantConversation> sendLocal(
      AssistantConversation? conversation, String input) async {
    final now = DateTime.now();
    final active = conversation ??
        AssistantConversation(
            id: 'conversation-${now.microsecondsSinceEpoch}',
            title: input.trim().length > 48
                ? '${input.trim().substring(0, 48)}…'
                : input.trim());
    final userMessage = AssistantMessage(
        id: 'message-${now.microsecondsSinceEpoch}',
        role: 'user',
        content: input.trim(),
        mode: 'local_rule',
        createdAt: now);
    final result = _localResponse(input);
    final assistantMessage = AssistantMessage(
        id: 'message-${now.microsecondsSinceEpoch + 1}',
        role: 'assistant',
        content: result.content,
        mode: 'local_rule',
        reasoning: result.reasoning,
        actions: result.actions,
        createdAt: now);
    final saved = active.copyWith(
        messages: [...active.messages, userMessage, assistantMessage]);
    await _saveConversations([
      saved,
      ...(await loadConversations()).where((item) => item.id != saved.id)
    ]);
    return saved;
  }

  Future<AssistantMemory> saveMemory(String content) async {
    final memory = AssistantMemory(
        id: 'memory-${DateTime.now().microsecondsSinceEpoch}',
        content: content.trim(),
        memoryType: 'preference',
        importance: 70,
        pinned: true);
    await _preferences.setString(
        _memoriesKey,
        jsonEncode(
            [...(await loadMemories()).map(_memoryJson), _memoryJson(memory)]));
    return memory;
  }

  Future<void> _saveConversations(
          List<AssistantConversation> conversations) async =>
      _preferences.setString(_conversationsKey,
          jsonEncode(conversations.map(_conversationJson).toList()));

  Map<String, dynamic> _conversationJson(AssistantConversation conversation) =>
      {
        'id': conversation.id,
        'title': conversation.title,
        'scope': conversation.scope,
        'pinned': conversation.pinned,
        'archived': conversation.archived,
        'messages': conversation.messages
            .map((message) => {
                  'id': message.id,
                  'role': message.role,
                  'content': message.content,
                  'mode': message.mode,
                  'reasoning': message.reasoning,
                  'sources': message.sources
                      .map((source) => {
                            'source_type': source.sourceType,
                            'source_id': source.sourceId,
                            'title': source.title,
                            'excerpt': source.excerpt,
                            'route': source.route
                          })
                      .toList(),
                  'actions': message.actions
                      .map((action) => {
                            'action_type': action.actionType,
                            'label': action.label,
                            'status': action.status,
                            'payload': action.payload
                          })
                      .toList(),
                  'created_at': message.createdAt?.toIso8601String()
                })
            .toList()
      };
  Map<String, dynamic> _memoryJson(AssistantMemory memory) => {
        'id': memory.id,
        'content': memory.content,
        'memory_type': memory.memoryType,
        'importance': memory.importance,
        'pinned': memory.pinned,
        'archived': memory.archived
      };
}

class _LocalResponse {
  const _LocalResponse(this.content, this.reasoning, [this.actions = const []]);
  final String content;
  final String reasoning;
  final List<AssistantAction> actions;
}

_LocalResponse _localResponse(String input) {
  final text = input.trim().toLowerCase();
  if (text.contains('overdue') && text.contains('task')) {
    return const _LocalResponse(
      'I can check overdue tasks when the local task index is connected. For now, open Smart Tasks to review the queue.',
      'The offline client recognized an overdue-task request and kept the response local.',
      [
        AssistantAction(
            actionType: 'navigate',
            label: 'Open Smart Tasks',
            payload: {'route': '/tasks'})
      ],
    );
  }
  if (text.contains('today') &&
      (text.contains('meeting') || text.contains('calendar'))) {
    return const _LocalResponse(
      'Your local calendar brief is ready to review. Open Calendar to see today’s events and conflicts.',
      'The offline client recognized a daily calendar request.',
      [
        AssistantAction(
            actionType: 'navigate',
            label: 'Open Calendar',
            payload: {'route': '/calendar'})
      ],
    );
  }
  if (text.contains('plan my week') || text.contains('plan the week')) {
    return const _LocalResponse(
      'Start with one high-priority task, protect a morning focus block, and leave recovery space around meetings. I prepared this as a recommendation, not an automatic change.',
      'The fallback plan uses the executive-agent rules: priority first, focus protection, and no silent schedule mutations.',
      [
        AssistantAction(
            actionType: 'navigate',
            label: 'Open Calendar',
            payload: {'route': '/calendar'}),
        AssistantAction(
            actionType: 'navigate',
            label: 'Open Smart Tasks',
            payload: {'route': '/tasks'}),
      ],
    );
  }
  if (text.startsWith('find ') || text.startsWith('search ')) {
    return const _LocalResponse(
      'I will search your local workspace across tasks, notes, and calendar content when those indexes are available. No data leaves this device.',
      'The fallback keeps global search local and privacy-preserving.',
      [
        AssistantAction(
            actionType: 'navigate',
            label: 'Open Second Brain Notes',
            payload: {'route': '/notes'})
      ],
    );
  }
  if (text.startsWith('open ') || text.startsWith('show ')) {
    for (final entry in {
      'dashboard': ('Dashboard', '/'),
      'tasks': ('Smart Tasks', '/tasks'),
      'calendar': ('Calendar', '/calendar'),
      'notes': ('Second Brain Notes', '/notes')
    }.entries) {
      if (text.contains(entry.key)) {
        return _LocalResponse(
          'Opening ${entry.value.$1}.',
          'The command explicitly requested navigation to ${entry.value.$1}.',
          [
            AssistantAction(
                actionType: 'navigate',
                label: 'Open ${entry.value.$1}',
                payload: {'route': entry.value.$2})
          ],
        );
      }
    }
  }
  if (text.startsWith('create task')) {
    return _LocalResponse(
      'I prepared a task preview from “${input.substring(12).trim()}”. Review it before saving.',
      'Creation is previewed locally so the assistant never silently mutates the workspace.',
      [
        AssistantAction(
            actionType: 'create_task',
            label: 'Review task preview',
            payload: {'title': input.substring(12).trim()})
      ],
    );
  }
  return const _LocalResponse(
      'I’m ready to help with tasks, calendar, notes, and workspace search. Try “show overdue tasks”, “summarize today’s meetings”, “plan my week”, “find React”, or “open notes”.',
      'No specialized local command matched, so the assistant returned safe productivity guidance.');
}
