import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../community/community_image_service.dart';
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
  final CommunityImageService _imageService = CommunityImageService();
  final ContactRepository _contactRepository = ContactRepository();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<DirectMessageModel> _messages = <DirectMessageModel>[];
  RealtimeChannel? _channel;
  Timer? _backgroundSyncTimer;
  bool _isSending = false;
  bool _isAllowed = false;
  bool _loadingPermission = true;
  bool _isLoadingMessages = false;
  bool _isRefreshingMessages = false;
  bool _readReceiptsEnabled = true;
  bool _expiringPhotosEnabled = true;
  String? _pendingPhotoUrl;

  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initialize();
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!mounted || !_isAllowed || _isLoadingMessages || _isSending) {
        return;
      }
      _refresh();
    });
  }

  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _readReceiptsEnabled = prefs.getBool('dm.read_receipts') ?? true;
      _expiringPhotosEnabled = prefs.getBool('dm.expiring_photos') ?? true;
    });
  }

  Future<void> _toggleReadReceipts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool next = !_readReceiptsEnabled;
    await prefs.setBool('dm.read_receipts', next);
    if (!mounted) {
      return;
    }
    setState(() {
      _readReceiptsEnabled = next;
    });
  }

  Future<void> _toggleExpiringPhotos() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool next = !_expiringPhotosEnabled;
    await prefs.setBool('dm.expiring_photos', next);
    if (!mounted) {
      return;
    }
    setState(() {
      _expiringPhotosEnabled = next;
    });
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

      _channel = _repository.subscribeToThread(
        otherUserId: widget.otherUserId,
        onMessage: () async {
          await _refresh();
        },
      );

      if (_readReceiptsEnabled) {
        await _repository.markThreadRead(widget.otherUserId);
      }

      if (!mounted) return;
      setState(() {
        _loadingPermission = false;
      });

      await _refresh(showLoading: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPermission = false;
        _isAllowed = false;
      });
    }
  }

  Future<void> _refresh({bool showLoading = false}) async {
    if (showLoading && _messages.isEmpty) {
      setState(() {
        _isLoadingMessages = true;
      });
    } else {
      setState(() {
        _isRefreshingMessages = true;
      });
    }

    try {
      final messages = await _repository.getMessages(widget.otherUserId);

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
      });

      if (_readReceiptsEnabled) {
        await _repository.markThreadRead(widget.otherUserId);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedLoadMessages', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
          _isRefreshingMessages = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    final String imageUrl = (_pendingPhotoUrl ?? '').trim();
    if (text.isEmpty && imageUrl.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _repository.sendMessage(
        recipientId: widget.otherUserId,
        body: text,
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
        expiresIn30Days: _expiringPhotosEnabled,
      );

      _messageController.clear();
      _pendingPhotoUrl = null;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedSendMessage', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isSending) {
      return;
    }

    try {
      final String? imageUrl = await _imageService.pickCropAndUploadCommunityImage(
        folder: 'dm',
      );
      if (!mounted || imageUrl == null || imageUrl.trim().isEmpty) {
        return;
      }
      setState(() {
        _pendingPhotoUrl = imageUrl;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $error')),
      );
    }
  }

  void _removePendingPhoto() {
    final String? imageUrl = _pendingPhotoUrl;
    setState(() {
      _pendingPhotoUrl = null;
    });
    _imageService.deleteUploadedImageByPublicUrl(imageUrl);
  }

  Future<void> _openMessageMenu(DirectMessageModel message) async {
    final bool isMine = message.senderId == _currentUserId;
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isMine)
                ListTile(
                  leading: const Icon(Icons.undo),
                  title: const Text('Unsend'),
                  onTap: () => Navigator.of(sheetContext).pop('unsend'),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    try {
      if (selected == 'unsend') {
        await _repository.unsendMessage(message.id);
      } else if (selected == 'delete') {
        await _repository.deleteMessage(message.id);
      }
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $error')),
      );
    }
  }

  void _openImageLightbox(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: Stack(
            children: <Widget>[
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loadingPermission) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherDisplayName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAllowed) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherDisplayName)),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              l10n.t('dmOnlyAccepted'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherDisplayName),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'read_receipts') {
                _toggleReadReceipts();
              } else if (value == 'expiring_photos') {
                _toggleExpiringPhotos();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              CheckedPopupMenuItem<String>(
                value: 'read_receipts',
                checked: _readReceiptsEnabled,
                child: const Text('Read receipts'),
              ),
              CheckedPopupMenuItem<String>(
                value: 'expiring_photos',
                checked: _expiringPhotosEnabled,
                child: const Text('Expire photo messages in 30 days'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isRefreshingMessages)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(l10n.t('noMessagesYet')),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMine = message.senderId == _currentUserId;
                          final ThemeData theme = Theme.of(context);
                          final ColorScheme colors = theme.colorScheme;
                          final bool isLightTheme =
                            theme.brightness == Brightness.light;
                          final Color bubbleColor = isMine
                            ? (isLightTheme
                              ? colors.primary.withValues(alpha: 0.18)
                              : colors.primaryContainer)
                            : colors.surfaceContainerHighest;
                          final Color messageTextColor = isMine
                            ? (isLightTheme
                              ? const Color(0xFF1C231B)
                              : colors.onPrimaryContainer)
                            : colors.onSurface;
                          final Color timestampColor = messageTextColor
                            .withValues(alpha: 0.72);

                          return Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: InkWell(
                              onLongPress: () => _openMessageMenu(message),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.72,
                                ),
                                decoration: BoxDecoration(
                                  color: bubbleColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((message.imageUrl ?? '').trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: InkWell(
                                          onTap: () => _openImageLightbox(
                                            message.imageUrl!.trim(),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: SizedBox(
                                              width: 140,
                                              height: 140,
                                              child: Image.network(
                                                message.imageUrl!,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      message.isUnsent
                                          ? '[Message unsent]'
                                          : message.body,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: messageTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatTime(message.createdAt),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: timestampColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if ((_pendingPhotoUrl ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => _openImageLightbox(
                                _pendingPhotoUrl!.trim(),
                              ),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: Image.network(
                                  _pendingPhotoUrl!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _isSending ? null : _removePendingPhoto,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: _isSending ? null : _pickAndUploadPhoto,
                        icon: const Icon(Icons.image_outlined),
                        tooltip: 'Add photo',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: l10n.t('writeMessage'),
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
                            : Text(l10n.t('send')),
                      ),
                    ],
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