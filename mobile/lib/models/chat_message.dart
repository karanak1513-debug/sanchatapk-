import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final String status; // 'sending', 'sent', 'delivered', 'seen'
  final DateTime? readAt;
  final bool isEdited;
  final bool isDeleted;
  final List<String> deletedForUids;
  final List<String> clearedBy;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    required this.status,
    this.readAt,
    this.isEdited = false,
    this.isDeleted = false,
    this.deletedForUids = const [],
    this.clearedBy = const [],
  });

  bool isSentByMe(String currentUid) => senderId == currentUid;
  bool isHiddenFor(String currentUid) =>
      deletedForUids.contains(currentUid) || clearedBy.contains(currentUid);

  bool get isSending => status == 'sending';
  bool get isSent => status == 'sent';
  bool get isDelivered => status == 'delivered';
  bool get isSeen => status == 'seen' || status == 'read';

  String get formattedTime {
    return DateFormat('hh:mm a').format(timestamp);
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChatMessage.fromMap(data, doc.id);
  }

  factory ChatMessage.fromMap(Map<String, dynamic> data, String id) {
    DateTime parsedTime = DateTime.now();
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      parsedTime = rawTs.toDate();
    } else if (rawTs is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (rawTs is String) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    }

    DateTime? parsedReadAt;
    final rawReadAt = data['readAt'];
    if (rawReadAt is Timestamp) {
      parsedReadAt = rawReadAt.toDate();
    } else if (rawReadAt is int) {
      parsedReadAt = DateTime.fromMillisecondsSinceEpoch(rawReadAt);
    }

    final rawDeletedFor = data['deletedFor'] ?? data['deletedForUids'];
    final List<String> parsedDeletedFor = [];
    if (rawDeletedFor is List) {
      for (var item in rawDeletedFor) {
        if (item != null) parsedDeletedFor.add(item.toString());
      }
    }

    final rawClearedBy = data['clearedBy'];
    final List<String> parsedClearedBy = [];
    if (rawClearedBy is List) {
      for (var item in rawClearedBy) {
        if (item != null) parsedClearedBy.add(item.toString());
      }
    }

    return ChatMessage(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      timestamp: parsedTime,
      status: data['status'] as String? ?? 'sent',
      readAt: parsedReadAt,
      isEdited: data['isEdited'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedForUids: parsedDeletedFor,
      clearedBy: parsedClearedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      if (isEdited) 'isEdited': isEdited,
      if (isDeleted) 'isDeleted': isDeleted,
      if (deletedForUids.isNotEmpty) 'deletedForUids': deletedForUids,
      if (deletedForUids.isNotEmpty) 'deletedFor': deletedForUids,
      if (clearedBy.isNotEmpty) 'clearedBy': clearedBy,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    String? status,
    DateTime? readAt,
    bool? isEdited,
    bool? isDeleted,
    List<String>? deletedForUids,
    List<String>? clearedBy,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      readAt: readAt ?? this.readAt,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedForUids: deletedForUids ?? this.deletedForUids,
      clearedBy: clearedBy ?? this.clearedBy,
    );
  }
}
