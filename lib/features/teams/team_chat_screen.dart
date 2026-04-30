import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/user_avatar.dart';
import 'team_collab_repository.dart';

class TeamChatScreen extends StatefulWidget {
  const TeamChatScreen({super.key, required this.teamId, required this.teamName});

  final String teamId;
  final String teamName;

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final TeamCollabRepository _repository = TeamCollabRepository();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _sending = false;

  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _send() async {
    if (_sending) {
      return;
    }

    final String body = _controller.text.trim();
    if (body.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _repository.sendTeamMessage(teamId: widget.teamId, body: body);
      _controller.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('teamMessageSendFailed', args: {'error': error.toString()}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('teamChatTitle', args: {'teamName': widget.teamName}))),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<List<TeamMessageModel>>(
              stream: _repository.watchMessages(widget.teamId),
              builder: (BuildContext context, AsyncSnapshot<List<TeamMessageModel>> snapshot) {
                final List<TeamMessageModel> messages = snapshot.data ?? const <TeamMessageModel>[];

                if (snapshot.connectionState == ConnectionState.waiting && messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Text(AppLocalizations.of(context).noTeamMessagesYet),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final TeamMessageModel message = messages[index];
                    final bool mine = message.userId == _uid;

                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Card(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHigh,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    UserAvatar(
                                      userId: message.userId,
                                      avatarUrl: message.senderAvatarUrl,
                                      initials: message.senderName,
                                      radius: 12,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        message.senderName ?? AppLocalizations.of(context).t('operator'),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(message.body),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(message.createdAt),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
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
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).teamMessageHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
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
    final DateTime local = value.toLocal();
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
