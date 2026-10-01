import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/errors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/remote/chats_remote.dart';
import '../../../data/repositories/chats_repository.dart';
import '../../common/common_widgets.dart';
import '../item_actions.dart';

/// A 1:1 text chat with live delivery (Supabase Realtime + RLS).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _messages = <ChatMessage>[];
  StreamSubscription<ChatMessage>? _live;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  ChatsRepository get _repo => ref.read(chatsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _live = _repo
        .newMessages(conversationId: widget.conversationId)
        .listen(_add);
    _load();
  }

  @override
  void dispose() {
    _live?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _loading = false;
      });
      _markRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userMessageFor(e);
      });
    }
  }

  void _add(ChatMessage m) {
    if (!mounted || _messages.any((x) => x.id == m.id)) return;
    setState(() {
      _messages
        ..add(m)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    _markRead();
  }

  Future<void> _markRead() async {
    if (_messages.isEmpty) return;
    await _repo.markRead(widget.conversationId, _messages.last.createdAt);
    if (mounted) ref.invalidate(chatsProvider);
  }

  Future<void> _send() async {
    final body = _text.text;
    if (body.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await _repo.send(widget.conversationId, body);
      _text.clear();
      _add(sent);
    } catch (e) {
      showSnack(userMessageFor(e), actionLabel: 'Retry', onAction: _send);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatsProvider);
    final summary = chats.value
        ?.where((c) => c.conversationId == widget.conversationId)
        .firstOrNull;
    // Not a member (or never existed): same message either way.
    final gone = !chats.isLoading && chats.hasValue && summary == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(summary == null ? 'Chat' : '@${summary.otherUsername}'),
      ),
      body: gone
          ? EmptyState(
              icon: Icons.forum_outlined,
              message: 'This chat no longer exists.',
              action: FilledButton.tonal(
                onPressed: () => context.go('/messenger'),
                child: const Text('Back to Messenger'),
              ),
            )
          : Column(
              children: [
                Expanded(child: _body(context)),
                _Composer(controller: _text, sending: _sending, onSend: _send),
              ],
            ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_messages.isEmpty) {
      return const EmptyState(
        icon: Icons.waving_hand_outlined,
        message: 'No messages yet — say hi!',
      );
    }
    final me = _repo.myId;
    // Reversed list: index 0 is the newest message, shown at the bottom.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final idx = _messages.length - 1 - i;
        final m = _messages[idx];
        final prev = idx > 0 ? _messages[idx - 1] : null;
        final showDate =
            prev == null || !isSameDay(prev.createdAt, m.createdAt);
        return Column(
          children: [
            if (showDate) _DateChip(label: daySeparatorLabel(m.createdAt)),
            _Bubble(message: m, mine: m.senderId == me),
          ],
        );
      },
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final fg = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: LinkifiedText(
                  text: message.body,
                  style: TextStyle(color: fg, fontSize: 15.5),
                  linkColor: scheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: fg.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text with tappable http(s) / www links.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    required this.linkColor,
  });
  final String text;
  final TextStyle? style;
  final Color linkColor;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  static final _url = RegExp(
    r'(https?://[^\s]+|www\.[^\s]+)',
    caseSensitive: false,
  );
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _url.allMatches(widget.text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      }
      var link = m.group(0)!;
      // Trailing punctuation is usually not part of the link.
      final trail = RegExp(r'[.,!?;:)\]]+$').firstMatch(link)?.group(0) ?? '';
      link = link.substring(0, link.length - trail.length);
      final href = link.toLowerCase().startsWith('www.')
          ? 'https://$link'
          : link;
      final r = TapGestureRecognizer()..onTap = () => openLink(href);
      _recognizers.add(r);
      spans
        ..add(
          TextSpan(
            text: link,
            recognizer: r,
            style: TextStyle(
              color: widget.linkColor,
              decoration: TextDecoration.underline,
              decorationColor: widget.linkColor,
            ),
          ),
        )
        ..add(TextSpan(text: trail));
      last = m.end;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 6,
                  maxLength: ChatsRepository.maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, _) => IconButton.filled(
                  tooltip: 'Send',
                  onPressed: sending || value.text.trim().isEmpty
                      ? null
                      : onSend,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a username and opens (or creates) the chat.
Future<void> startNewChat(BuildContext context, WidgetRef ref) async {
  final id = await showDialog<String>(
    context: context,
    builder: (_) => const _NewChatDialog(),
  );
  if (id != null && context.mounted) context.push('/chat/$id');
}

class _NewChatDialog extends ConsumerStatefulWidget {
  const _NewChatDialog();

  @override
  ConsumerState<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends ConsumerState<_NewChatDialog> {
  final _username = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(chatsRepositoryProvider).start(_username.text);
      ref.invalidate(chatsProvider);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) setState(() => _error = userMessageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New chat'),
    content: TextField(
      controller: _username,
      autofocus: true,
      autocorrect: false,
      maxLength: 21,
      decoration: InputDecoration(
        labelText: 'Username',
        prefixText: '@',
        errorText: _error,
        errorMaxLines: 3,
      ),
      onSubmitted: (_) => _busy ? null : _start(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _busy ? null : _start,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Start chat'),
      ),
    ],
  );
}
