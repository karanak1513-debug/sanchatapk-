import 'package:flutter/material.dart';
import '../models/chat_user.dart';
import 'chat_conversation_screen.dart';

export 'chat_conversation_screen.dart';

/// Backward-compatible wrapper for ChatScreen
class ChatScreen extends StatelessWidget {
  final ChatUser peer;

  const ChatScreen({
    super.key,
    required this.peer,
  });

  @override
  Widget build(BuildContext context) {
    return ChatConversationScreen(
      peerUid: peer.uid,
      peerName: peer.displayName,
      peerAvatar: peer.avatarUrl,
      peer: peer,
    );
  }
}
