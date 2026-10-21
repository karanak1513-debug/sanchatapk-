import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequest {
  final String requestId;
  final String senderUid;
  final String senderHandle;
  final String senderName;
  final String senderAvatar;
  final String receiverUid;
  final String receiverHandle;
  final String status; // 'pending' | 'accepted' | 'declined' | 'blocked'
  final DateTime updatedAt;
  final String? blockedBy;

  const FriendRequest({
    required this.requestId,
    required this.senderUid,
    required this.senderHandle,
    required this.senderName,
    required this.senderAvatar,
    required this.receiverUid,
    required this.receiverHandle,
    required this.status,
    required this.updatedAt,
    this.blockedBy,
  });

  String get senderId => senderUid;
  String get receiverId => receiverUid;
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isBlocked => status == 'blocked';

  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return FriendRequest.fromMap(data, doc.id);
  }

  factory FriendRequest.fromMap(Map<String, dynamic> data, String id) {
    DateTime parsedTime = DateTime.now();
    final rawTs = data['updatedAt'] ?? data['timestamp'];
    if (rawTs is Timestamp) {
      parsedTime = rawTs.toDate();
    } else if (rawTs is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (rawTs is String) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    }

    return FriendRequest(
      requestId: id,
      senderUid: (data['senderId'] ?? data['senderUid']) as String? ?? '',
      senderHandle: data['senderHandle'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      senderAvatar: data['senderAvatar'] as String? ?? '',
      receiverUid: (data['receiverId'] ?? data['receiverUid']) as String? ?? '',
      receiverHandle: data['receiverHandle'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      updatedAt: parsedTime,
      blockedBy: data['blockedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'senderUid': senderUid,
      'senderHandle': senderHandle,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'receiverUid': receiverUid,
      'receiverHandle': receiverHandle,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  FriendRequest copyWith({
    String? requestId,
    String? senderUid,
    String? senderHandle,
    String? senderName,
    String? senderAvatar,
    String? receiverUid,
    String? receiverHandle,
    String? status,
    DateTime? updatedAt,
  }) {
    return FriendRequest(
      requestId: requestId ?? this.requestId,
      senderUid: senderUid ?? this.senderUid,
      senderHandle: senderHandle ?? this.senderHandle,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      receiverUid: receiverUid ?? this.receiverUid,
      receiverHandle: receiverHandle ?? this.receiverHandle,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
