import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contact_repository.dart';
import 'direct_message_model.dart';
import 'direct_message_repository.dart';

class DirectMessageScreen extends StatefulWidget {
  const DirectMessageScreen({
    super.key,
    required this.otherUserId,
    required this.otherDisplayName,
  });

  final String otherUserId;
  final String otherDisplayName;

  @override
  State<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends State<DirectMessageScreen> {
  final DirectMessageRepository _repository = DirectMessageRepository();
  final ContactRepository _contactRepository = ContactRepository();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late Future<List<DirectMessageModel>> _futureMessages;
  RealtimeChannel? _channel;
  bool _isSending = false;
  bool _isAllowed = false;
  bool _loadingPermission = true;

  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _futureMessages = Future.value(const <DirectMessageModel>[]);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final allowed = await _contactRepository.areAcceptedContacts(
        widget.otherUserId,
      );

      if (!mounted) return;

      if (!allowed) {
        setState(() {
          _isAllowed = false;
          _loadingPermission = false;
        });
        return;
      }

      _isAllowed = true;
      _futureMessages = _repository.getMessages(widget.otherUserId);

      _channel = _repository.subscribeToThread(
        otherUserId: widget.otherUserId,
        onMessage: () async {
          await _refresh();
        },
      );

      await _repository.markThreadRead(widget.otherUserId);

      if (!mounted) return;
      setState(() {
        _loadingPermission = false;
      });

      await _refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPermission = false;
        _isAllowed = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _futureMessages = _repository.getMessages(widget.otherUserId);
    });

    await _futureMessages;
    await _repository.markThreadRead(widget.otherUserId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _repository.sendMessage(
        recipientId: widget.otherUserId,
        body: text,
      );

      _messageController.clear();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPermission) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherDisplayName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAllowed) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherDisplayName)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Direct messaging is only available for accepted contacts.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherDisplayName)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<DirectMessageModel>>(
              future: _futureMessages,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load messages:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet.'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == _currentUserId;

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message.body),
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(message.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSending ? null : _send,
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}