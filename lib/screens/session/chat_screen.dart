import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class ChatScreen extends StatefulWidget {
  final String sessionId;
  final List<String> memberIds;

  const ChatScreen({
    super.key,
    required this.sessionId,
    required this.memberIds,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestore = FirestoreService();
  final _textController = TextEditingController();
  bool _isSending = false;

  Map<String, AppUser> _memberProfiles = {};

  @override
  void initState() {
    super.initState();
    _loadMemberProfiles();
  }

  Future<void> _loadMemberProfiles() async {
    final users = await _firestore.getUsersByIds(widget.memberIds);
    if (!mounted) return;

    setState(() {
      _memberProfiles = {for (final u in users) u.uid: u};
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) return;

    setState(() => _isSending = true);

    try {
      await _firestore.sendMessage(
        sessionId: widget.sessionId,
        senderId: userId,
        text: text,
      );
      _textController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send message.')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _firestore.streamMessages(widget.sessionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load chat.'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const _EmptyChat();
                }

                final reversed = messages.reversed.toList();

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  itemCount: reversed.length,
                  itemBuilder: (context, index) {
                    final message = reversed[index];
                    final isMe = message.senderId == currentUserId;
                    final sender = _memberProfiles[message.senderId];

                    return _MessageBubble(
                      message: message,
                      sender: sender,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          _MessageComposer(
            controller: _textController,
            isSending: _isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ---------------- EMPTY ----------------

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 60),
            const SizedBox(height: 12),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start the conversation 🎵',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- MESSAGE ----------------

class _MessageBubble extends StatelessWidget {
  final Message message;
  final AppUser? sender;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.sender,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor =
        isMe ? scheme.primary : scheme.surfaceContainerHighest;
    final textColor = isMe ? scheme.onPrimary : scheme.onSurface;

    final senderName = sender?.displayName ?? 'Member';
    final time = message.sentAt;
    final timeStr = time != null ? DateFormat.jm().format(time) : '';

    final avatar = (sender?.avatarUrl != null &&
            sender!.avatarUrl!.isNotEmpty)
        ? CircleAvatar(
            radius: 14,
            backgroundImage:
                CachedNetworkImageProvider(sender!.avatarUrl!),
          )
        : CircleAvatar(
            radius: 14,
            child: Text(
              senderName.isEmpty ? '?' : senderName[0].toUpperCase(),
              style: const TextStyle(fontSize: 12),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            avatar,
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Text(
                      senderName,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(color: textColor),
                  ),
                ),
                if (timeStr.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 2, left: 4, right: 4),
                    child: Text(
                      timeStr,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- INPUT ----------------

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: const Color.fromARGB(255, 12, 5, 56),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary,
              child: IconButton(
                onPressed: isSending ? null : onSend,
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}