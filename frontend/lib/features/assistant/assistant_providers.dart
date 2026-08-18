import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/assistant_repository.dart';
import 'assistant_models.dart';

final assistantControllerProvider =
    AsyncNotifierProvider<AssistantController, AssistantState>(
        AssistantController.new);

class AssistantState {
  const AssistantState(
      {required this.conversations,
      required this.memories,
      this.activeConversationId});
  final List<AssistantConversation> conversations;
  final List<AssistantMemory> memories;
  final String? activeConversationId;

  AssistantConversation? get activeConversation => conversations
      .where((conversation) => conversation.id == activeConversationId)
      .firstOrNull;
  List<AssistantConversation> get recentConversations => [...conversations]
    ..sort((a, b) => b.messages.length.compareTo(a.messages.length));

  AssistantState copyWith(
          {List<AssistantConversation>? conversations,
          List<AssistantMemory>? memories,
          String? activeConversationId}) =>
      AssistantState(
          conversations: conversations ?? this.conversations,
          memories: memories ?? this.memories,
          activeConversationId:
              activeConversationId ?? this.activeConversationId);
}

class AssistantController extends AsyncNotifier<AssistantState> {
  AssistantRepository? _repository;

  @override
  Future<AssistantState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = AssistantRepository(preferences);
    final conversations = await _repository!.loadConversations();
    final memories = await _repository!.loadMemories();
    return AssistantState(
        conversations: conversations,
        memories: memories,
        activeConversationId: conversations.firstOrNull?.id);
  }

  Future<void> send(String input) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null || input.trim().isEmpty) return;
    final saved =
        await _repository!.sendLocal(current.activeConversation, input);
    final conversations = [
      saved,
      ...current.conversations
          .where((conversation) => conversation.id != saved.id)
    ];
    state = AsyncData(current.copyWith(
        conversations: conversations, activeConversationId: saved.id));
  }

  Future<void> newConversation() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final conversation = AssistantConversation(
        id: 'conversation-${DateTime.now().microsecondsSinceEpoch}',
        title: 'New conversation');
    state = AsyncData(current.copyWith(
        conversations: [conversation, ...current.conversations],
        activeConversationId: conversation.id));
  }

  Future<void> selectConversation(String conversationId) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(activeConversationId: conversationId));
    }
  }

  Future<void> saveMemory(String content) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null || content.trim().isEmpty) {
      return;
    }
    final memory = await _repository!.saveMemory(content);
    state =
        AsyncData(current.copyWith(memories: [memory, ...current.memories]));
  }
}
