import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import 'auth_service.dart';
import 'friend_service.dart';
import 'notification_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  ChatService._internal();

  FirebaseFirestore get _db => AuthService.firestoreInstance;
  String get currentUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  // In-memory optimistic message buffer keyed by chatId
  final Map<String, List<ChatMessage>> _optimisticBuffer = {};
  final Map<String, StreamController<List<ChatMessage>>> _streamControllers = {};
  final Map<String, StreamSubscription> _firestoreSubscriptions = {};
  final Map<String, List<ChatMessage>> _lastFirestoreMessages = {};

  /// Composite deterministic Chat ID:
  /// Always sorts uids alphabetically to guarantee 1-on-1 consistency
  static String getDeterministicChatId(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 'unknown_chat';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
  }

  String getChatId(String a, String b) => getDeterministicChatId(a, b);

  /// Normalize a username into a lowercase, alphanumeric handle
  static String normalizeUsername(String input) {
    var clean = input.trim().toLowerCase();
    if (clean.startsWith('@')) clean = clean.substring(1);
    clean = clean.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (clean.isEmpty) {
      clean = 'user_${DateTime.now().millisecondsSinceEpoch % 100000}';
    }
    return clean;
  }

  /// 1. Instant Message Sending with Immediate Optimistic UI
  /// Appends the message locally to the stream controller with status = 'sending'
  /// and executes an unblocked Firestore batch write in the background.
  Future<ChatMessage> sendMessage(String peerUid, String text, [String? senderUid]) async {
    final myUid = senderUid ?? currentUid;
    final cleanText = text.trim();
    if (myUid.isEmpty || peerUid.isEmpty || cleanText.isEmpty) {
      throw ArgumentError('Invalid sender, receiver, or empty message text');
    }

    final chatId = getChatId(myUid, peerUid);
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';

    // Build the optimistic message
    final optimisticMessage = ChatMessage(
      id: tempId,
      senderId: myUid,
      receiverId: peerUid,
      text: cleanText,
      timestamp: DateTime.now(),
      status: 'sending',
    );

    // 1. Immediately inject into local optimistic buffer
    _optimisticBuffer.putIfAbsent(chatId, () => []);
    _optimisticBuffer[chatId]!.insert(0, optimisticMessage);
    _emitCombinedMessages(chatId);

    // 2. Perform background Firestore batch write
    () async {
      try {
        final chatDoc = _db.collection('chats').doc(chatId);
        final msgDoc = chatDoc.collection('messages').doc();

        final batch = _db.batch();
        batch.set(msgDoc, {
          'id': msgDoc.id,
          'senderId': myUid,
          'receiverId': peerUid,
          'text': cleanText,
          'status': 'sent',
          'timestamp': FieldValue.serverTimestamp(),
        });

        batch.set(chatDoc, {
          'chatId': chatId,
          'participants': [myUid, peerUid],
          'lastMessage': cleanText,
          'lastTimestamp': FieldValue.serverTimestamp(),
          'unreadCount': {
            peerUid: FieldValue.increment(1),
          },
        }, SetOptions(merge: true));

        await batch.commit();

        // Remove the temporary message from buffer once committed
        _optimisticBuffer[chatId]?.removeWhere((m) => m.id == tempId);
        _emitCombinedMessages(chatId);
      } catch (e) {
        debugPrint('Error sending message to Firestore: $e');
        // Mark optimistic message as failed
        final idx = _optimisticBuffer[chatId]?.indexWhere((m) => m.id == tempId) ?? -1;
        if (idx != -1 && _optimisticBuffer[chatId] != null) {
          _optimisticBuffer[chatId]![idx] = optimisticMessage.copyWith(status: 'failed');
          _emitCombinedMessages(chatId);
        }
      }
    }();

    return optimisticMessage;
  }

  /// 2. Live Status Delivery Engine: Single Grey Tick ('sent') -> Double Grey Tick ('delivered')
  /// When receiver is online and active, batch update unread incoming messages from 'sent' to 'delivered'
  Future<void> markMessagesAsDelivered(String chatId, [String? receiverUid]) async {
    final myUid = receiverUid ?? currentUid;
    if (myUid.isEmpty || chatId.isEmpty) return;

    try {
      final unreadQuery = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: myUid)
          .where('status', isEqualTo: 'sent')
          .get();

      if (unreadQuery.docs.isEmpty) return;

      final batch = _db.batch();
      for (var doc in unreadQuery.docs) {
        batch.update(doc.reference, {
          'status': 'delivered',
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as delivered: $e');
    }
  }

  /// 3. Live Status Delivery Engine: Double Blue Tick ('seen')
  /// When receiver opens ChatConversationScreen, execute an instant batch write updating
  /// all messages where receiverId == currentUid && status != 'seen' to status = 'seen'
  /// and clear the unread badge on the parent chat room doc.
  Future<void> markMessagesAsSeen(String peerUid, [String? viewerUid]) async {
    final myUid = viewerUid ?? currentUid;
    if (myUid.isEmpty || peerUid.isEmpty) return;

    final chatId = getChatId(peerUid, myUid);
    try {
      final unreadQuery = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: myUid)
          .where('status', isNotEqualTo: 'seen')
          .get();

      final batch = _db.batch();
      for (var doc in unreadQuery.docs) {
        batch.update(doc.reference, {
          'status': 'seen',
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      batch.set(_db.collection('chats').doc(chatId), {
        'unreadCount': {myUid: 0}
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as seen: $e');
    }
  }

  /// 4. Stream messages for a chat combining real-time Firestore stream with optimistic writes
  /// Ordered descending (newest first) for reverse ListView rendering.
  /// Uses limit(30) to optimize Firebase Free Spark Tier read quotas.
  Stream<List<ChatMessage>> getMessagesStream(String chatId, {int limit = 30}) {
    if (chatId.isEmpty) return Stream.value([]);

    if (!_streamControllers.containsKey(chatId) || _streamControllers[chatId]!.isClosed) {
      final controller = StreamController<List<ChatMessage>>.broadcast();
      _streamControllers[chatId] = controller;

      // Subscribe to Firestore message documents with limit(30)
      _firestoreSubscriptions[chatId]?.cancel();
      try {
        _firestoreSubscriptions[chatId] = _db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .snapshots()
            .listen((snapshot) {
          final firestoreList = snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
          _lastFirestoreMessages[chatId] = firestoreList;

          // Clean out optimistic messages that already appeared in Firestore
          final pending = _optimisticBuffer[chatId];
          if (pending != null && pending.isNotEmpty) {
            pending.removeWhere((opt) =>
                firestoreList.any((fs) => fs.senderId == opt.senderId && fs.text == opt.text));
          }

          _emitCombinedMessages(chatId);
        }, onError: (err) {
          debugPrint('Firestore messages stream error: $err');
        });
      } catch (e) {
        debugPrint('Could not initialize firestore messages stream for $chatId: $e');
      }
    }

    // Trigger initial emission if cached
    _emitCombinedMessages(chatId);
    return _streamControllers[chatId]!.stream;
  }

  void _emitCombinedMessages(String chatId) {
    final controller = _streamControllers[chatId];
    if (controller == null || controller.isClosed) return;

    final myUid = currentUid;
    final firestoreMsgs = _lastFirestoreMessages[chatId] ?? [];
    final optimisticMsgs = _optimisticBuffer[chatId] ?? [];

    // Filter out messages hidden for current user via Delete for Me or Clear Chat
    final combined = <ChatMessage>[
      ...optimisticMsgs,
      ...firestoreMsgs,
    ].where((m) => myUid.isEmpty || !m.isHiddenFor(myUid)).toList();

    controller.add(combined);
  }

  /// 5. Stream active chats for the current user (deduplicated by peer UID)
  Stream<List<ChatRoom>> getUserChatsStream([String? userUid]) {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty) return Stream.value([]);

    return _db
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .orderBy('lastTimestamp', descending: true)
        .snapshots()
        .map((snap) {
          final rawRooms = snap.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList();
          final Map<String, ChatRoom> deduplicated = {};
          for (final room in rawRooms) {
            final peerUid = room.getPeerUid(myUid);
            if (peerUid.isEmpty) continue;
            final canonicalId = getDeterministicChatId(myUid, peerUid);
            final existing = deduplicated[peerUid];
            if (existing == null) {
              deduplicated[peerUid] = room;
            } else {
              // Prefer canonical room ID or the one with newer lastTimestamp
              if (room.chatId == canonicalId) {
                deduplicated[peerUid] = room;
              } else if (existing.chatId != canonicalId &&
                  room.lastTimestamp.isAfter(existing.lastTimestamp)) {
                deduplicated[peerUid] = room;
              }
            }
          }
          final list = deduplicated.values.toList();
          list.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
          return list;
        });
  }

  /// Dynamic Total Unread Count Stream for Top-Level App Bar Badging
  Stream<int> getTotalUnreadCountStream([String? userUid]) {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty) return Stream.value(0);

    return getUserChatsStream(myUid).map((rooms) {
      int total = 0;
      for (var room in rooms) {
        total += room.getUnreadFor(myUid);
      }
      return total;
    });
  }

  /// 6. Fast Debounced User Search Engine (Bug 4 Implementation)
  /// Supports:
  /// - Display Name search (displayName_lowercase prefix query)
  /// - @handle search (handle_lowercase prefix query)
  /// - Exact UID direct lookup
  /// - Result deduplication: merged results shown exactly once
  Future<List<ChatUser>> searchUsers(String rawQuery) async {
    final myUid = currentUid;
    final cleanInput = rawQuery.trim();
    final normalizedQuery = cleanInput.toLowerCase();
    var handleQuery = normalizedQuery;
    if (handleQuery.startsWith('@')) handleQuery = handleQuery.substring(1);

    final Map<String, ChatUser> resultsMap = {};

    try {
      // A. Empty Query: Fetch most recently active users from public_profiles
      if (cleanInput.isEmpty) {
        try {
          final snapshot = await _db.collection('public_profiles').limit(20).get();
          for (var doc in snapshot.docs) {
            if (doc.id == myUid) continue;
            resultsMap[doc.id] = ChatUser.fromMap(doc.data(), doc.id);
          }
        } catch (_) {}

        if (resultsMap.isEmpty) {
          final snapshot = await _db
              .collection('users')
              .orderBy('lastSeen', descending: true)
              .limit(20)
              .get()
              .catchError((_) => _db.collection('users').limit(20).get());

          for (var doc in snapshot.docs) {
            if (doc.id == myUid) continue;
            resultsMap[doc.id] = ChatUser.fromFirestore(doc);
          }
        }
        return resultsMap.values.toList();
      }

      // 1. UID FALLBACK & EXACT DOCUMENT LOOKUP
      // If query is an exact doc ID / UID
      try {
        final docSnap = await _db.collection('public_profiles').doc(cleanInput).get();
        if (docSnap.exists && docSnap.id != myUid) {
          resultsMap[docSnap.id] = ChatUser.fromMap(docSnap.data()!, docSnap.id);
        }
      } catch (_) {}

      try {
        final uidMatch = await _db
            .collection('public_profiles')
            .where('uid', isEqualTo: cleanInput)
            .limit(5)
            .get();
        for (var doc in uidMatch.docs) {
          if (doc.id != myUid) {
            resultsMap[doc.id] = ChatUser.fromMap(doc.data(), doc.id);
          }
        }
      } catch (_) {}

      // 2. HANDLE SEARCH (using handle_lowercase prefix range query)
      if (handleQuery.isNotEmpty) {
        try {
          final handleLowerSnap = await _db
              .collection('public_profiles')
              .where('handle_lowercase', isGreaterThanOrEqualTo: handleQuery)
              .where('handle_lowercase', isLessThanOrEqualTo: '$handleQuery\uf8ff')
              .limit(20)
              .get();
          for (var doc in handleLowerSnap.docs) {
            if (doc.id != myUid) {
              resultsMap[doc.id] = ChatUser.fromMap(doc.data(), doc.id);
            }
          }
        } catch (_) {}

        // Fallback on legacy 'handle' field
        try {
          final handleSnap = await _db
              .collection('public_profiles')
              .where('handle', isGreaterThanOrEqualTo: handleQuery)
              .where('handle', isLessThanOrEqualTo: '$handleQuery\uf8ff')
              .limit(10)
              .get();
          for (var doc in handleSnap.docs) {
            if (doc.id != myUid) {
              resultsMap.putIfAbsent(doc.id, () => ChatUser.fromMap(doc.data(), doc.id));
            }
          }
        } catch (_) {}
      }

      // 3. DISPLAY NAME SEARCH (using displayName_lowercase prefix range query)
      if (normalizedQuery.isNotEmpty) {
        try {
          final nameLowerSnap = await _db
              .collection('public_profiles')
              .where('displayName_lowercase', isGreaterThanOrEqualTo: normalizedQuery)
              .where('displayName_lowercase', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
              .limit(20)
              .get();
          for (var doc in nameLowerSnap.docs) {
            if (doc.id != myUid) {
              resultsMap.putIfAbsent(doc.id, () => ChatUser.fromMap(doc.data(), doc.id));
            }
          }
        } catch (_) {}

        // Fallback on legacy 'displayName'
        try {
          final nameSnap = await _db
              .collection('public_profiles')
              .where('displayName', isGreaterThanOrEqualTo: cleanInput)
              .where('displayName', isLessThanOrEqualTo: '$cleanInput\uf8ff')
              .limit(10)
              .get();
          for (var doc in nameSnap.docs) {
            if (doc.id != myUid) {
              resultsMap.putIfAbsent(doc.id, () => ChatUser.fromMap(doc.data(), doc.id));
            }
          }
        } catch (_) {}
      }

      // 4. Fallback search against users collection if still empty
      if (resultsMap.isEmpty) {
        try {
          final userDoc = await _db.collection('users').doc(cleanInput).get();
          if (userDoc.exists && userDoc.id != myUid) {
            resultsMap[userDoc.id] = ChatUser.fromFirestore(userDoc);
          }
        } catch (_) {}

        try {
          final usernameSnap = await _db
              .collection('users')
              .where('username', isEqualTo: handleQuery)
              .limit(10)
              .get();
          for (var doc in usernameSnap.docs) {
            if (doc.id != myUid) {
              resultsMap.putIfAbsent(doc.id, () => ChatUser.fromFirestore(doc));
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error searching users in Firestore: $e');
    }

    return resultsMap.values.toList();
  }

  // =========================================================================
  // Mutual Friend Request & Chat Permission Engine
  // Friend Request Statuses: 'none', 'pending_sent', 'pending_received', 'accepted'
  // Collections:
  // - users/{uid}/friends/{peerUid} with {status: 'pending_sent', timestamp: ...}
  // - users/{peerUid}/friends/{uid} with {status: 'pending_received', timestamp: ...}
  // =========================================================================

  /// Stream friendship status for a given peer
  Stream<String> getFriendshipStatusStream(String peerUid, [String? userUid]) {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty || peerUid.isEmpty) return Stream.value('none');

    return _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(peerUid)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return 'none';
      final data = snap.data()!;
      final status = (data['status'] as String?) ?? 'none';
      if (status == 'declined') return 'none';
      if (status == 'pending') {
        final senderId = data['senderId'] as String?;
        if (senderId == myUid) return 'pending_sent';
        return 'pending_received';
      }
      return status;
    });
  }

  /// Get friendship status once
  Future<String> getFriendshipStatus(String peerUid, [String? userUid]) async {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty || peerUid.isEmpty) return 'none';

    try {
      final doc = await _db
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(peerUid)
          .get();
      if (!doc.exists || doc.data() == null) return 'none';
      final data = doc.data()!;
      final status = (data['status'] as String?) ?? 'none';
      if (status == 'declined') return 'none';
      if (status == 'pending') {
        final senderId = data['senderId'] as String?;
        if (senderId == myUid) return 'pending_sent';
        return 'pending_received';
      }
      return status;
    } catch (e) {
      debugPrint('Error getting friendship status: $e');
      return 'none';
    }
  }

  /// Send friend request to a peer:
  /// - users/{uid}/friends/{peerUid} -> {status: 'pending', senderId: uid, receiverId: peerUid}
  /// - users/{peerUid}/friends/{uid} -> {status: 'pending', senderId: uid, receiverId: peerUid}
  /// - friends/{relationId} -> {status: 'pending', senderId: uid, receiverId: peerUid}
  Future<void> sendFriendRequest(String peerUid, [ChatUser? peer, String? userUid]) async {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty || peerUid.isEmpty) return;

    try {
      await FriendService.sendFriendRequest(
        targetUid: peerUid,
        targetName: peer?.displayName,
        targetHandle: peer?.username,
      );

      // Best-effort cache in current user's personal friends collection only
      try {
        await _db
            .collection('users')
            .doc(myUid)
            .collection('friends')
            .doc(peerUid)
            .set({
          'uid': peerUid,
          'senderId': myUid,
          'receiverId': peerUid,
          'status': 'pending',
          'displayName': peer?.displayName ?? '',
          'handle': peer?.username ?? '',
          'email': peer?.email ?? '',
          'avatarUrl': peer?.avatarUrl ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      rethrow;
    }
  }

  /// Accept incoming friend request:
  /// Updates friend_requests/{peerUid}_{myUid} to accepted and creates deterministic chats/{chatId}
  Future<void> acceptFriendRequest(String peerUid, [String? userUid]) async {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty || peerUid.isEmpty) return;

    try {
      final requestId = '${peerUid}_$myUid';
      await FriendService.acceptFriendRequest(requestId, peerUid, myUid);

      // Best-effort local write to my user doc
      try {
        await _db
            .collection('users')
            .doc(myUid)
            .collection('friends')
            .doc(peerUid)
            .set({
          'status': 'accepted',
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      // Ensure 1-on-1 chat room exists
      await initializeChat(peerUid, myUid);
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      rethrow;
    }
  }

  /// Decline friend request:
  /// Deletes friend_requests document and cleans up local references
  Future<void> declineFriendRequest(String peerUid, [String? userUid]) async {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty || peerUid.isEmpty) return;

    try {
      final req1 = '${peerUid}_$myUid';
      await FriendService.rejectFriendRequest(req1);

      // Best-effort cleanup for my user doc
      try {
        await _db
            .collection('users')
            .doc(myUid)
            .collection('friends')
            .doc(peerUid)
            .delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('Error declining friend request: $e');
      rethrow;
    }
  }

  /// Adds a peer (backward compatibility helper)
  Future<void> addFriend(String targetUid, ChatUser peer, [String? userUid]) async {
    await sendFriendRequest(targetUid, peer, userUid);
  }

  /// Stream of accepted friend UIDs for current user
  Stream<Set<String>> getFriendUidsStream([String? userUid]) {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty) return Stream.value({});

    return _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .snapshots()
        .map((snap) => snap.docs
            .where((d) => (d.data()['status'] as String?) == 'accepted')
            .map((d) => d.id)
            .toSet());
  }

  /// Ensures a 1-on-1 chat document exists in chats/{chatId}
  Future<String> initializeChat(String targetUid, [String? userUid]) async {
    final myUid = userUid ?? currentUid;
    final chatId = getChatId(myUid, targetUid);

    try {
      final chatDoc = _db.collection('chats').doc(chatId);
      await chatDoc.set({
        'chatId': chatId,
        'participants': [myUid, targetUid],
        'lastTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error initializing chat: $e');
    }

    return chatId;
  }

  // =========================================================================
  // Message Management: Edit, Delete & Clear Chat History
  // =========================================================================

  /// Edit Message (Only if senderId == currentUid):
  /// Updates 'text' and sets 'isEdited: true' in Firestore message doc
  Future<void> editMessage({
    required String peerUid,
    required String messageId,
    required String newText,
    String? userUid,
  }) async {
    final myUid = userUid ?? currentUid;
    final clean = newText.trim();
    if (clean.isEmpty || myUid.isEmpty) return;

    final chatId = getChatId(myUid, peerUid);
    try {
      final msgRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      await msgRef.update({
        'text': clean,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      // Update in local buffer if present
      final list = _lastFirestoreMessages[chatId];
      if (list != null) {
        final idx = list.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(text: clean, isEdited: true);
          _emitCombinedMessages(chatId);
        }
      }
    } catch (e) {
      debugPrint('Error editing message: $e');
      rethrow;
    }
  }

  /// Hard-Delete Single Message:
  /// Physically removes document from chats/{chatId}/messages/{messageId}
  /// and updates parent chat summary lastMessage preview
  static Future<bool> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
  }) async {
    if (chatId.isEmpty || messageId.isEmpty) return false;

    final db = _instance._db;
    try {
      final messageRef = db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      // Physically delete the message document
      await messageRef.delete();

      // Check remaining messages to update lastMessage preview
      final latestDocs = await db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      final parentDoc = db.collection('chats').doc(chatId);
      if (latestDocs.docs.isNotEmpty) {
        final latest = latestDocs.docs.first.data();
        await parentDoc.update({
          'lastMessage': latest['text'] ?? '',
          'lastMessageTimestamp': latest['timestamp'] ?? FieldValue.serverTimestamp(),
        });
      } else {
        await parentDoc.update({
          'lastMessage': '',
        });
      }

      // Also clean up local in-memory buffers if applicable
      final instance = _instance;
      final list = instance._lastFirestoreMessages[chatId];
      if (list != null) {
        list.removeWhere((m) => m.id == messageId);
        instance._emitCombinedMessages(chatId);
      }
      final opt = instance._optimisticBuffer[chatId];
      if (opt != null) {
        opt.removeWhere((m) => m.id == messageId);
        instance._emitCombinedMessages(chatId);
      }

      return true;
    } catch (e) {
      debugPrint('Error executing delete for everyone: $e');
      return false;
    }
  }

  /// Delete for Me:
  /// Appends current UID to deletedForUids list on message doc; do not render for current user
  Future<void> deleteMessageForMe({
    required String peerUid,
    required String messageId,
    String? userUid,
  }) async {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty) return;

    final chatId = getChatId(myUid, peerUid);
    try {
      final msgRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      await msgRef.update({
        'deletedForUids': FieldValue.arrayUnion([myUid]),
        'deletedFor': FieldValue.arrayUnion([myUid]),
      });

      final list = _lastFirestoreMessages[chatId];
      if (list != null) {
        final idx = list.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final updatedList = List<String>.from(list[idx].deletedForUids)..add(myUid);
          list[idx] = list[idx].copyWith(deletedForUids: updatedList);
          _emitCombinedMessages(chatId);
        }
      }
    } catch (e) {
      debugPrint('Error deleting message for me: $e');
      rethrow;
    }
  }

  /// Batch Hard-Delete for "Clear Chat":
  /// Query all message documents under chats/{chatId}/messages and physically delete them in chunks/batches.
  /// Also resets lastMessage preview in parent chat doc to save space.
  Future<void> clearEntireChatHistory(String chatId) async {
    if (chatId.isEmpty) return;

    final messagesRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages');

    try {
      // Safely delete in chunks of 400 to prevent batch limit exhaustion
      while (true) {
        final snapshots = await messagesRef.limit(400).get();
        if (snapshots.docs.isEmpty) break;

        final batch = _db.batch();
        for (final doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (snapshots.docs.length < 400) break;
      }

      // Reset lastMessage preview in parent chat doc
      final chatDocRef = _db.collection('chats').doc(chatId);
      await chatDocRef.update({
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': <String, dynamic>{},
      });

      _optimisticBuffer[chatId]?.clear();
      _lastFirestoreMessages[chatId] = [];
      _emitCombinedMessages(chatId);
    } catch (e) {
      debugPrint('Error executing batch clear chat: $e');
      rethrow;
    }
  }

  /// Per-user history clearing ("Clear for Me")
  Future<void> clearChatHistoryForMe({
    required String chatId,
    required String userUid,
  }) async {
    if (chatId.isEmpty || userUid.isEmpty) return;
    try {
      final messagesRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages');

      final snapshots = await messagesRef.limit(400).get();
      final batch = _db.batch();
      for (final doc in snapshots.docs) {
        batch.update(doc.reference, {
          'clearedBy': FieldValue.arrayUnion([userUid]),
          'deletedForUids': FieldValue.arrayUnion([userUid]),
        });
      }
      await batch.commit();

      final list = _lastFirestoreMessages[chatId];
      if (list != null) {
        _lastFirestoreMessages[chatId] = list
            .where((m) => !m.clearedBy.contains(userUid) && !m.deletedForUids.contains(userUid))
            .toList();
      }
      _optimisticBuffer[chatId]?.clear();
      _emitCombinedMessages(chatId);
    } catch (e) {
      debugPrint('Error clearing chat history for user: $e');
      rethrow;
    }
  }

  /// Backward-compatible wrapper calling clearChatHistoryForMe
  Future<void> clearChatHistory({
    String? peerUid,
    String? chatId,
    String? userUid,
  }) async {
    final effectiveChatId = (chatId != null && chatId.isNotEmpty)
        ? chatId
        : getChatId(userUid ?? currentUid, peerUid ?? '');
    final effectiveUid = userUid ?? currentUid;

    await clearChatHistoryForMe(chatId: effectiveChatId, userUid: effectiveUid);
  }

  /// Safe migration utility for existing duplicate conversations belonging to the same two users
  Future<void> migrateLegacyDuplicateChats([String? userUid]) async {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty) return;

    try {
      final snap = await _db
          .collection('chats')
          .where('participants', arrayContains: myUid)
          .get();

      final Map<String, List<DocumentSnapshot>> roomsByPeer = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final peer = participants.firstWhere((p) => p != myUid, orElse: () => '');
        if (peer.isNotEmpty) {
          roomsByPeer.putIfAbsent(peer, () => []).add(doc);
        }
      }

      for (final entry in roomsByPeer.entries) {
        final peerUid = entry.key;
        final docs = entry.value;
        if (docs.length > 1) {
          final canonicalId = getDeterministicChatId(myUid, peerUid);
          final canonicalRef = _db.collection('chats').doc(canonicalId);

          for (final oldDoc in docs) {
            if (oldDoc.id != canonicalId) {
              final msgsSnap = await oldDoc.reference.collection('messages').get();
              for (final msgDoc in msgsSnap.docs) {
                final targetMsgRef = canonicalRef.collection('messages').doc(msgDoc.id);
                final exists = (await targetMsgRef.get()).exists;
                if (!exists) {
                  await targetMsgRef.set(msgDoc.data());
                }
              }
              await oldDoc.reference.set({
                'isObsolete': true,
                'migratedTo': canonicalId,
              }, SetOptions(merge: true));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error migrating duplicate chats: $e');
    }
  }

  /// Hard-delete the parent chats/{chatId} document and purge subcollection messages
  Future<void> deleteEntireChatThread(String chatId) async {
    if (chatId.isEmpty) return;

    try {
      final messagesRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages');

      while (true) {
        final snapshots = await messagesRef.limit(400).get();
        if (snapshots.docs.isEmpty) break;

        final batch = _db.batch();
        for (final doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (snapshots.docs.length < 400) break;
      }

      final chatDocRef = _db.collection('chats').doc(chatId);
      await chatDocRef.delete();

      _optimisticBuffer[chatId]?.clear();
      _lastFirestoreMessages[chatId] = [];
      _emitCombinedMessages(chatId);
      _streamControllers[chatId]?.close();
      _streamControllers.remove(chatId);
      _firestoreSubscriptions[chatId]?.cancel();
      _firestoreSubscriptions.remove(chatId);
    } catch (e) {
      debugPrint('Error hard-deleting entire chat thread: $e');
    }
  }

  /// 7. Get specific user details with authoritative public_profiles resolution
  Future<ChatUser?> getUser(String uid) async {
    if (uid.isEmpty) return null;
    try {
      // 1. Authoritative: public_profiles/{uid}
      final profileDoc = await _db.collection('public_profiles').doc(uid).get();
      if (profileDoc.exists && profileDoc.data() != null) {
        return ChatUser.fromMap(profileDoc.data()!, uid);
      }

      // 2. Fallback: users/{uid}
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return ChatUser.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error getting user $uid: $e');
    }
    return null;
  }

  /// 8. Background Delivery Watcher: auto-marks incoming messages as 'delivered'
  /// and triggers push/local notification for incoming unread messages
  StreamSubscription? startDeliveryWatcher() {
    final myUid = currentUid;
    if (myUid.isEmpty) return null;

    try {
      return _db
          .collection('chats')
          .where('participants', arrayContains: myUid)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          final data = change.doc.data();
          final chatId = change.doc.id;
          final unreadForMe = (data?['unreadCount'] as Map?)?[myUid] ?? 0;
          if (unreadForMe > 0) {
            markMessagesAsDelivered(chatId, myUid);
            if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
              final lastMsg = (data?['lastMessage'] as String?) ?? '';
              final participants = (data?['participants'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final senderId = participants.firstWhere((p) => p != myUid, orElse: () => '');
              if (lastMsg.isNotEmpty && senderId.isNotEmpty) {
                getUser(senderId).then((sender) {
                  NotificationService().showChatMessageNotification(
                    senderName: sender?.displayName ?? 'New Message',
                    messageText: lastMsg,
                    chatId: chatId,
                  );
                });
              }
            }
          }
        }
      }, onError: (e) {
        debugPrint('Delivery watcher stream error: $e');
      });
    } catch (e) {
      debugPrint('Error starting delivery watcher: $e');
      return null;
    }
  }

  /// 9. User Directory Indexing: Ensure every user document in Firestore (users/{userId})
  /// contains normalized searchable fields:
  /// uid, displayName, username, email, avatarUrl, lastSeen
  Future<void> syncCurrentUserProfile([String? customHandle]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final effectiveName = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : (user.email?.split('@').first ?? 'User');
      final effectiveEmail = user.email ?? '';
      final effectiveAvatar = user.photoURL ?? '';

      final username = customHandle != null && customHandle.trim().isNotEmpty
          ? normalizeUsername(customHandle)
          : (effectiveEmail.contains('@')
              ? normalizeUsername(effectiveEmail.split('@').first)
              : normalizeUsername(effectiveName));

      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'userId': user.uid,
        'displayName': effectiveName,
        'displayName_lowercase': effectiveName.trim().toLowerCase(),
        'name': effectiveName,
        'username': username,
        'handle': username,
        'handle_lowercase': username.trim().toLowerCase(),
        'email': effectiveEmail,
        'avatarUrl': effectiveAvatar,
        'photoUrl': effectiveAvatar,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('public_profiles').doc(user.uid).set({
        'uid': user.uid,
        'displayName': effectiveName,
        'displayName_lowercase': effectiveName.trim().toLowerCase(),
        'handle': username,
        'handle_lowercase': username.trim().toLowerCase(),
        'avatarUrl': effectiveAvatar,
        'isVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing user profile in users collection: $e');
    }
  }

  void disposeChatStream(String chatId) {
    _firestoreSubscriptions[chatId]?.cancel();
    _firestoreSubscriptions.remove(chatId);
    _streamControllers[chatId]?.close();
    _streamControllers.remove(chatId);
    _optimisticBuffer.remove(chatId);
    _lastFirestoreMessages.remove(chatId);
  }
}
