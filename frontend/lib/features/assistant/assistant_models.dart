class AssistantSource {
  const AssistantSource(
      {required this.sourceType,
      required this.sourceId,
      required this.title,
      this.excerpt = '',
      this.route});
  final String sourceType;
  final String sourceId;
  final String title;
  final String excerpt;
  final String? route;

  factory AssistantSource.fromJson(Map<String, dynamic> json) =>
      AssistantSource(
          sourceType: json['source_type'] as String? ?? 'workspace',
          sourceId: json['source_id'] as String? ?? '',
          title: json['title'] as String? ?? '',
          excerpt: json['excerpt'] as String? ?? '',
          route: json['route'] as String?);
}

class AssistantAction {
  const AssistantAction(
      {required this.actionType,
      required this.label,
      this.status = 'preview',
      this.payload = const {}});
  final String actionType;
  final String label;
  final String status;
  final Map<String, dynamic> payload;

  factory AssistantAction.fromJson(Map<String, dynamic> json) =>
      AssistantAction(
          actionType: json['action_type'] as String? ?? 'unknown',
          label: json['label'] as String? ?? '',
          status: json['status'] as String? ?? 'preview',
          payload: (json['payload'] as Map<dynamic, dynamic>? ?? const {})
              .map((key, value) => MapEntry('$key', value)));
}

class AssistantMessage {
  const AssistantMessage(
      {required this.id,
      required this.role,
      required this.content,
      required this.mode,
      this.reasoning = '',
      this.sources = const [],
      this.actions = const [],
      this.createdAt});
  final String id;
  final String role;
  final String content;
  final String mode;
  final String reasoning;
  final List<AssistantSource> sources;
  final List<AssistantAction> actions;
  final DateTime? createdAt;

  bool get isUser => role == 'user';

  factory AssistantMessage.fromJson(Map<String, dynamic> json) =>
      AssistantMessage(
          id: json['id'] as String? ?? '',
          role: json['role'] as String? ?? 'assistant',
          content: json['content'] as String? ?? '',
          mode: json['mode'] as String? ?? 'local_rule',
          reasoning: json['reasoning'] as String? ?? '',
          sources: (json['sources'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(AssistantSource.fromJson)
              .toList(),
          actions: (json['actions'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(AssistantAction.fromJson)
              .toList(),
          createdAt: _date(json['created_at'] ?? json['createdAt']));
}

class AssistantConversation {
  const AssistantConversation(
      {required this.id,
      required this.title,
      this.messages = const [],
      this.scope = 'workspace',
      this.pinned = false,
      this.archived = false});
  final String id;
  final String title;
  final List<AssistantMessage> messages;
  final String scope;
  final bool pinned;
  final bool archived;

  AssistantConversation copyWith(
          {String? title, List<AssistantMessage>? messages}) =>
      AssistantConversation(
          id: id,
          title: title ?? this.title,
          messages: messages ?? this.messages,
          scope: scope,
          pinned: pinned,
          archived: archived);

  factory AssistantConversation.fromJson(Map<String, dynamic> json) =>
      AssistantConversation(
          id: json['id'] as String? ?? '',
          title: json['title'] as String? ?? 'Conversation',
          scope: json['scope'] as String? ?? 'workspace',
          pinned: json['pinned'] as bool? ?? false,
          archived: json['archived'] as bool? ?? false,
          messages: (json['messages'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(AssistantMessage.fromJson)
              .toList());
}

class AssistantMemory {
  const AssistantMemory(
      {required this.id,
      required this.content,
      this.memoryType = 'workspace',
      this.importance = 50,
      this.pinned = false,
      this.archived = false});
  final String id;
  final String content;
  final String memoryType;
  final double importance;
  final bool pinned;
  final bool archived;

  factory AssistantMemory.fromJson(Map<String, dynamic> json) =>
      AssistantMemory(
          id: json['id'] as String? ?? '',
          content: json['content'] as String? ?? '',
          memoryType: json['memory_type'] as String? ?? 'workspace',
          importance: json['importance'] is num
              ? (json['importance'] as num).toDouble()
              : 50,
          pinned: json['pinned'] as bool? ?? false,
          archived: json['archived'] as bool? ?? false);
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
