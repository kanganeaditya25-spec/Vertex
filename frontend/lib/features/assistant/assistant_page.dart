import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'assistant_models.dart';
import 'assistant_providers.dart';

class AssistantPage extends ConsumerWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistant = ref.watch(assistantControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Executive Assistant'), actions: [
        IconButton(
            tooltip: 'New conversation',
            onPressed: () => ref
                .read(assistantControllerProvider.notifier)
                .newConversation(),
            icon: const Icon(Icons.add_comment_rounded)),
        const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(
                avatar: Icon(Icons.cloud_off_rounded, size: 16),
                label: Text('Local mode')))
      ]),
      body: assistant.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _AssistantError(
              message: error.toString(),
              retry: () => ref.invalidate(assistantControllerProvider)),
          data: (state) => _AssistantWorkspace(state: state)),
    );
  }
}

class _AssistantWorkspace extends ConsumerWidget {
  const _AssistantWorkspace({required this.state});
  final AssistantState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final sidebar = _ConversationSidebar(state: state);
    final chat = state.activeConversation == null
        ? _AssistantWelcome(state: state)
        : _AssistantChat(conversation: state.activeConversation!);
    if (wide) {
      return Row(children: [
        SizedBox(width: 300, child: sidebar),
        const VerticalDivider(width: 1),
        Expanded(child: chat)
      ]);
    }
    return Column(children: [
      SizedBox(height: 170, child: sidebar),
      const Divider(height: 1),
      Expanded(child: chat)
    ]);
  }
}

class _ConversationSidebar extends ConsumerWidget {
  const _ConversationSidebar({required this.state});
  final AssistantState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(assistantControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Conversations',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
                tooltip: 'New conversation',
                onPressed: controller.newConversation,
                icon: const Icon(Icons.add_rounded))
          ]),
          Expanded(
            child: state.conversations.isEmpty
                ? const Text('Start a conversation with a command.')
                : ListView.builder(
                    itemCount: state.conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = state.conversations[index];
                      return ListTile(
                          selected:
                              conversation.id == state.activeConversationId,
                          leading:
                              const Icon(Icons.chat_bubble_outline_rounded),
                          title: Text(conversation.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle:
                              Text('${conversation.messages.length} messages'),
                          onTap: () =>
                              controller.selectConversation(conversation.id));
                    },
                  ),
          ),
          const SizedBox(height: 8),
          _MemorySummary(memories: state.memories),
        ],
      ),
    );
  }
}

class _AssistantWelcome extends ConsumerWidget {
  const _AssistantWelcome({required this.state});
  final AssistantState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompts = [
      'Show overdue tasks',
      'Summarize today’s meetings',
      'Plan my week',
      'Find React',
      'Open notes'
    ];
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 72),
                  const SizedBox(height: 14),
                  Text('Your local executive assistant',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                      'Ask FocusFlow to search, plan, explain, and navigate across your workspace. The fallback remains useful without a running model.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: prompts
                          .map((prompt) => ActionChip(
                              label: Text(prompt),
                              onPressed: () {
                                ref
                                    .read(assistantControllerProvider.notifier)
                                    .newConversation();
                                ref
                                    .read(assistantControllerProvider.notifier)
                                    .send(prompt);
                              }))
                          .toList()),
                ],
              ),
            ),
          ),
        ),
        const _AssistantInput(),
      ],
    );
  }
}

class _AssistantChat extends ConsumerWidget {
  const _AssistantChat({required this.conversation});
  final AssistantConversation conversation;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              children: [
                Text(conversation.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (conversation.messages.isEmpty)
                  const _EmptyConversation()
                else
                  ...conversation.messages
                      .map((message) => _MessageCard(message: message))
              ]),
        ),
        const _AssistantInput()
      ]);
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final AssistantMessage message;
  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          color: user
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.55),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                      user
                          ? Icons.person_outline_rounded
                          : Icons.auto_awesome_rounded,
                      size: 18),
                  const SizedBox(width: 8),
                  Text(user ? 'You' : 'Assistant',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (!user) ...[
                    const Spacer(),
                    const Chip(
                        label: Text('Local reasoning'),
                        visualDensity: VisualDensity.compact)
                  ]
                ]),
                const SizedBox(height: 10),
                SelectableText(message.content,
                    style: Theme.of(context).textTheme.bodyLarge),
                if (!user && message.reasoning.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.55)),
                      child: Text('Why: ${message.reasoning}',
                          style: Theme.of(context).textTheme.bodySmall)),
                ],
                if (message.actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: message.actions
                          .map((action) => _ActionButton(action: action))
                          .toList())
                ],
                if (message.sources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Sources',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  ...message.sources
                      .take(5)
                      .map((source) => _SourceRow(source: source))
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});
  final AssistantAction action;
  @override
  Widget build(BuildContext context) {
    final route = action.payload['route'];
    return OutlinedButton.icon(
        onPressed: route is String ? () => context.push(route) : null,
        icon: Icon(
            action.status == 'preview'
                ? Icons.visibility_outlined
                : Icons.play_arrow_rounded,
            size: 18),
        label: Text(action.label));
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});
  final AssistantSource source;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(_sourceIcon(source.sourceType)),
      title: Text(source.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          source.excerpt.isEmpty ? source.sourceType : source.excerpt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      trailing: source.route == null
          ? null
          : const Icon(Icons.arrow_forward_rounded, size: 16));
}

class _AssistantInput extends ConsumerStatefulWidget {
  const _AssistantInput();
  @override
  ConsumerState<_AssistantInput> createState() => _AssistantInputState();
}

class _AssistantInputState extends ConsumerState<_AssistantInput> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(assistantControllerProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                        hintText: 'Ask your executive assistant…',
                        prefixIcon: const Icon(Icons.auto_awesome_rounded),
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none)))),
            const SizedBox(width: 8),
            IconButton.filled(
                tooltip: 'Send command',
                onPressed: _send,
                icon: const Icon(Icons.arrow_upward_rounded))
          ])));
}

class _MemorySummary extends ConsumerWidget {
  const _MemorySummary({required this.memories});
  final List<AssistantMemory> memories;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.psychology_alt_outlined),
            const SizedBox(width: 8),
            Expanded(
                child: Text('${memories.length} local memories',
                    style: Theme.of(context).textTheme.bodySmall)),
            IconButton(
                tooltip: 'Remember a preference',
                onPressed: () => _remember(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18))
          ]),
        ),
      );
}

Future<void> _remember(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
              title: const Text('Remember locally'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText:
                          'Example: I prefer quiet focus blocks before lunch.',
                      border: OutlineInputBorder())),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(
                        dialogContext, controller.text.trim().isNotEmpty),
                    child: const Text('Remember'))
              ]));
  if (saved == true) {
    await ref
        .read(assistantControllerProvider.notifier)
        .saveMemory(controller.text);
  }
  controller.dispose();
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child:
          Center(child: Text('Ask a question or choose a command to begin.')));
}

class _AssistantError extends StatelessWidget {
  const _AssistantError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.auto_awesome_rounded, size: 52),
        const SizedBox(height: 12),
        const Text('Assistant could not load'),
        Text(message),
        const SizedBox(height: 12),
        FilledButton(onPressed: retry, child: const Text('Retry'))
      ]));
}

IconData _sourceIcon(String type) => switch (type) {
      'task' => Icons.checklist_rounded,
      'note' => Icons.menu_book_rounded,
      'calendar' => Icons.calendar_month_rounded,
      _ => Icons.description_outlined
    };
