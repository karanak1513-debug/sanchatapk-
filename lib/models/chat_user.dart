import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUser {
  final String uid;
  final String displayName;
  final String username;
  final String email;
  final String avatarUrl;
  final bool isVerified;
  final DateTime? lastSeen;
  final DateTime? lastActive;

  const ChatUser({
    required this.uid,
    String? name,
    String? displayName,
    this.username = '',
    required this.email,
    this.avatarUrl = '',
    this.isVerified = false,
    this.lastSeen,
    this.lastActive,
  }) : displayName = displayName ?? name ?? '';

  String get name => displayName;

  String get handle {
    if (username.isNotEmpty) return '@$username';
    if (email.contains('@')) {
      final prefix = email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
      return '@$prefix';
    }
    return '@$uidSnippet';
  }

  String get uidSnippet => uid.length > 8 ? uid.substring(0, 8) : uid;

  String get initials {
    final clean = displayName.trim();
    if (clean.isNotEmpty) {
      final parts = clean.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return clean.substring(0, 1).toUpperCase();
    }
    if (username.isNotEmpty) return username.substring(0, 1).toUpperCase();
    if (email.isNotEmpty) return email.substring(0, 1).toUpperCase();
    return 'U';
  }

  bool get isOnline {
    final active = lastSeen ?? lastActive;
    if (active == null) return false;
    return DateTime.now().difference(active).inMinutes < 5;
  }

  factory ChatUser.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChatUser.fromMap(data, doc.id);
  }

  factory ChatUser.fromMap(Map<String, dynamic> data, String uid) {
    DateTime? parsedSeen;
    final rawSeen = data['lastSeen'] ?? data['lastActive'] ?? data['updatedAt'];
    if (rawSeen is Timestamp) {
      parsedSeen = rawSeen.toDate();
    } else if (rawSeen is int) {
      parsedSeen = DateTime.fromMillisecondsSinceEpoch(rawSeen);
    }

    final rawName = data['displayName'] as String? ?? data['name'] as String? ?? '';
    final rawEmail = data['email'] as String? ?? '';
    final rawUsername = data['username'] as String? ?? data['handle'] as String? ?? '';
    final normalizedUsername = rawUsername.isNotEmpty
        ? rawUsername.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '')
        : (rawEmail.contains('@')
            ? rawEmail.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '')
            : (rawName.isNotEmpty
                ? rawName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '')
                : ''));

    final effectiveDisplayName = rawName.isNotEmpty
        ? rawName
        : (normalizedUsername.isNotEmpty
            ? normalizedUsername
            : (rawEmail.contains('@') ? rawEmail.split('@').first : 'User $uid'));

    return ChatUser(
      uid: uid,
      displayName: effectiveDisplayName,
      username: normalizedUsername,
      email: rawEmail,
      avatarUrl: data['avatarUrl'] as String? ?? data['photoUrl'] as String? ?? '',
      isVerified: (data['isVerified'] as bool?) ?? false,
      lastSeen: parsedSeen,
      lastActive: parsedSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'name': displayName,
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'isVerified': isVerified,
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
      if (lastActive != null) 'lastActive': Timestamp.fromDate(lastActive!),
    };
  }
}

class ChatRoom {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastTimestamp;
  final Map<String, int> unreadCount;

  const ChatRoom({
    required this.chatId,
    required this.participants,
    required this.lastMessage,
    required this.lastTimestamp,
    required this.unreadCount,
  });

  String getPeerUid(String currentUid) {
    return participants.firstWhere((id) => id != currentUid, orElse: () => '');
  }

  int getUnreadFor(String currentUid) {
    return unreadCount[currentUid] ?? 0;
  }

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChatRoom.fromMap(data, doc.id);
  }

  factory ChatRoom.fromMap(Map<String, dynamic> data, String chatId) {
    DateTime parsedTime = DateTime.now();
    final rawTs = data['lastTimestamp'] ?? data['updatedAt'];
    if (rawTs is Timestamp) {
      parsedTime = rawTs.toDate();
    } else if (rawTs is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
    }

    final rawParticipants = data['participants'] ?? data['users'];
    final participants = <String>[];
    if (rawParticipants is List) {
      for (var p in rawParticipants) {
        if (p is String) participants.add(p);
      }
    }

    final rawUnread = data['unreadCount'];
    final unreadMap = <String, int>{};
    if (rawUnread is Map) {
      rawUnread.forEach((key, value) {
        if (key is String && value is num) {
          unreadMap[key] = value.toInt();
        }
      });
    }

    return ChatRoom(
      chatId: chatId,
      participants: participants,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastTimestamp: parsedTime,
      unreadCount: unreadMap,
    );
  }
}
