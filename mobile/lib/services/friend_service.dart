import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/friend_request.dart';
import 'auth_service.dart';
import 'notification_service.dart';

/// Real-time Two-Way Friend Request & Friendship Permission Service
class FriendService {
  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal();

  FirebaseFirestore get _db => AuthService.firestoreInstance;

  String get currentUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Composite deterministic Chat ID:
  /// Alphabetically sorted UIDs guaranteeing 1-on-1 consistency
  String getChatId(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 'unknown_chat';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
  }

  /// Deterministic request ID format: `${sender}_${receiver}`
  String getReqId(String sender, String receiver) => '${sender}_$receiver';

  /// Backward-compatible alias
  String getRequestId(String senderUid, String receiverUid) => getReqId(senderUid, receiverUid);

  static FirebaseFirestore get _firestore => AuthService.firestoreInstance;

  // 1. Send Friend Request (Atomic ID: senderUid_targetUid)
  static Future<void> sendFriendRequest({
    required String targetUid,
    String? targetName,
    String? targetHandle,
  }) async {
    final myUser = FirebaseAuth.instance.currentUser;
    final currentUid = myUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      throw StateError('You must be logged in to send a friend request.');
    }
    if (currentUid == targetUid) {
      throw ArgumentError('You cannot add yourself.');
    }

    final db = _firestore;

    // Check if request already exists in either direction
    final docId = '${currentUid}_$targetUid';
    final existingDoc = await db.collection('friend_requests').doc(docId).get();
    if (existingDoc.exists) {
      final status = existingDoc.data()?['status'] as String?;
      if (status == 'pending') {
        throw StateError('Friend request already sent.');
      }
      if (status == 'accepted') {
        throw StateError('You are already friends.');
      }
    }

    final reverseId = '${targetUid}_$currentUid';
    final reverseDoc = await db.collection('friend_requests').doc(reverseId).get();
    if (reverseDoc.exists) {
      final status = reverseDoc.data()?['status'] as String?;
      if (status == 'pending') {
        // Reverse pending request exists: auto-accept!
        await acceptFriendRequest(reverseId, targetUid, currentUid);
        return;
      }
      if (status == 'accepted') {
        throw StateError('You are already friends.');
      }
    }

    // Fetch authoritative current user profile
    final myProfile = await db.collection('public_profiles').doc(currentUid).get();
    final myData = myProfile.data() ?? {};
    final senderName = (myData['displayName'] as String?)?.trim().isNotEmpty == true
        ? myData['displayName']
        : (myUser?.displayName ?? 'Sanchat User');
    final senderHandle = (myData['handle'] as String?)?.trim().isNotEmpty == true
        ? myData['handle']
        : (myUser?.email?.contains('@') == true ? myUser!.email!.split('@').first : 'user');
    final senderAvatar = (myData['avatarUrl'] as String?) ?? (myUser?.photoURL ?? '');

    await db.collection('friend_requests').doc(docId).set({
      'id': docId,
      'senderId': currentUid,
      'senderUid': currentUid,
      'senderName': senderName,
      'senderHandle': senderHandle,
      'senderAvatar': senderAvatar,
      'receiverId': targetUid,
      'receiverUid': targetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 2. Accept Friend Request (Creates Deterministic Chat Room)
  static Future<void> acceptFriendRequest(String requestId, String senderId, String receiverId) async {
    final db = _firestore;
    final batch = db.batch();
    
    // Mark Request Accepted
    final reqRef = db.collection('friend_requests').doc(requestId);
    batch.set(reqRef, {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Generate Standard Lexicographical Chat ID
    final chatId = senderId.compareTo(receiverId) < 0 
        ? '${senderId}_$receiverId' 
        : '${receiverId}_$senderId';
    
    final chatRef = db.collection('chats').doc(chatId);
    batch.set(chatRef, {
      'id': chatId,
      'chatId': chatId,
      'participants': [senderId, receiverId],
      'lastMessage': 'Friend request accepted. Start chatting!',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // 3. Reject / Delete Friend Request
  static Future<void> rejectFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  /// Backward-compatible alias for rejectFriendRequest
  static Future<void> declineFriendRequest(String requestId) => rejectFriendRequest(requestId);

  /// Cancel outgoing request sent by current user
  Future<void> cancelFriendRequest(String peerUid) async {
    final myUid = currentUid;
    if (myUid.isEmpty || peerUid.isEmpty) return;
    await rejectFriendRequest('${myUid}_$peerUid');
  }

  // ---------------------------------------------------------------------------
  // 4. Block User
  // ---------------------------------------------------------------------------
  /// Block: Update status = 'blocked', append blockedBy: currentUid.
  /// Both users can no longer see each other in search or chat.
  Future<void> blockUser({
    required String targetUid,
    String? currentUserId,
  }) async {
    final myUid = currentUserId ?? currentUid;
    if (myUid.isEmpty || targetUid.isEmpty) return;

    final batch = _db.batch();

    // 1. Update friend_requests both directions with status: 'blocked', blockedBy: myUid
    final incomingReqId = getReqId(targetUid, myUid);
    final outgoingReqId = getReqId(myUid, targetUid);

    final inDoc = _db.collection('friend_requests').doc(incomingReqId);
    batch.set(inDoc, {
      'status': 'blocked',
      'blockedBy': myUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final outDoc = _db.collection('friend_requests').doc(outgoingReqId);
    batch.set(outDoc, {
      'status': 'blocked',
      'blockedBy': myUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Mark friend record as blocked on both users
    final myFriendRef = _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(targetUid);
    batch.set(myFriendRef, {
      'uid': targetUid,
      'status': 'blocked',
      'blockedBy': myUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final peerFriendRef = _db
        .collection('users')
        .doc(targetUid)
        .collection('friends')
        .doc(myUid);
    batch.set(peerFriendRef, {
      'uid': myUid,
      'status': 'blocked',
      'blockedBy': myUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Add to blocked collection for quick query
    final blockedDoc = _db
        .collection('users')
        .doc(myUid)
        .collection('blocked')
        .doc(targetUid);
    batch.set(blockedDoc, {
      'blockedUid': targetUid,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    debugPrint('User $targetUid blocked by $myUid');
  }

  /// Stream of blocked user IDs for current user
  Stream<Set<String>> getBlockedUserIdsStream([String? uid]) {
    final myUid = uid ?? currentUid;
    if (myUid.isEmpty) return Stream.value({});

    return _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .where('status', isEqualTo: 'blocked')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  // ---------------------------------------------------------------------------
  // 4. Live Friendship Status Stream between Current User and Peer
  // ---------------------------------------------------------------------------
  /// Returns one of:
  /// - `null`: No relation
  /// - `'outgoing_pending'`: Current user sent request (Button shows: ⏳ Waiting for Response)
  /// - `'incoming_pending'`: Peer sent request to current user
  /// - `'accepted'`: Mutual friends, chat unlocked
  /// - `'declined'`: Declined
  Stream<String?> getFriendshipStatusStream(String peerUid, [String? userUid]) {
    final myUid = userUid ?? currentUid;
    if (myUid.isEmpty || peerUid.isEmpty) return Stream.value(null);

    final outgoingReqDoc = _db.collection('friend_requests').doc('${myUid}_$peerUid');
    final incomingReqDoc = _db.collection('friend_requests').doc('${peerUid}_$myUid');

    late StreamController<String?> controller;
    StreamSubscription? subOutgoing;
    StreamSubscription? subIncoming;

    String? outgoingStatus;
    String? incomingStatus;

    void evaluate() {
      if (controller.isClosed) return;

      if (outgoingStatus == 'blocked' || incomingStatus == 'blocked') {
        controller.add('blocked');
        return;
      }
      if (outgoingStatus == 'accepted' || incomingStatus == 'accepted') {
        controller.add('accepted');
        return;
      }
      // If outgoing document exists with status: 'pending', button shows ⏳ Waiting for Response
      if (outgoingStatus == 'pending' || outgoingStatus == 'outgoing_pending') {
        controller.add('outgoing_pending');
        return;
      }
      // If incoming document exists with status: 'pending', receiver sees incoming request
      if (incomingStatus == 'pending' || incomingStatus == 'incoming_pending') {
        controller.add('incoming_pending');
        return;
      }
      controller.add(null);
    }

    controller = StreamController<String?>.broadcast(
      onListen: () {
        subOutgoing = outgoingReqDoc.snapshots().listen((snap) {
          if (snap.exists && snap.data() != null) {
            outgoingStatus = snap.data()!['status'] as String?;
          } else {
            outgoingStatus = null;
          }
          evaluate();
        }, onError: (_) => evaluate());

        subIncoming = incomingReqDoc.snapshots().listen((snap) {
          if (snap.exists && snap.data() != null) {
            incomingStatus = snap.data()!['status'] as String?;
          } else {
            incomingStatus = null;
          }
          evaluate();
        }, onError: (_) => evaluate());
      },
      onCancel: () {
        subOutgoing?.cancel();
        subIncoming?.cancel();
      },
    );

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // 5. Incoming Pending Friend Requests Stream for Notification Badges
  // ---------------------------------------------------------------------------
  Stream<List<FriendRequest>> getIncomingRequestsStream([String? uid]) {
    final myUid = uid ?? currentUid;
    if (myUid.isEmpty) return Stream.value([]);

    return _db
        .collection('friend_requests')
        .where('receiverId', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FriendRequest.fromFirestore(d)).toList());
  }

  /// Count stream of pending incoming requests
  Stream<int> getIncomingRequestsCountStream([String? uid]) {
    return getIncomingRequestsStream(uid).map((list) => list.length);
  }

  /// 6. Background Listener: triggers notification when a new friend request arrives
  StreamSubscription? startFriendRequestListener() {
    final myUid = currentUid;
    if (myUid.isEmpty) return null;

    try {
      return _db
          .collection('friend_requests')
          .where('receiverId', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final req = FriendRequest.fromFirestore(change.doc);
            NotificationService().showFriendRequestNotification(
              senderName: req.senderName.isNotEmpty ? req.senderName : 'Someone',
              senderHandle: req.senderHandle.isNotEmpty ? '@${req.senderHandle}' : '',
            );
          }
        }
      }, onError: (e) {
        debugPrint('Friend request listener error: $e');
      });
    } catch (e) {
      debugPrint('Error starting friend request listener: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 7. Accepted Friend UIDs Stream
  // ---------------------------------------------------------------------------
  Stream<Set<String>> getAcceptedFriendUidsStream([String? uid]) {
    final myUid = uid ?? currentUid;
    if (myUid.isEmpty) return Stream.value({});

    return _db
        .collection('friend_requests')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) {
      final uids = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final sId = (data['senderId'] ?? data['senderUid']) as String?;
        final rId = (data['receiverId'] ?? data['receiverUid']) as String?;
        if (sId == myUid && rId != null && rId.isNotEmpty) uids.add(rId);
        if (rId == myUid && sId != null && sId.isNotEmpty) uids.add(sId);
      }
      return uids;
    });
  }

  // ---------------------------------------------------------------------------
  // 8. Registered Users Discovery (Excludes Current Logged-In User)
  // ---------------------------------------------------------------------------
  /// Fetches registered users in Sanchay Connect search modal, filtering out current logged-in user:
  Future<List<Map<String, dynamic>>> fetchRegisteredUsers({String? query}) async {
    final List<Map<String, dynamic>> users = [];
    final currentUser = FirebaseAuth.instance.currentUser;
    final myUid = currentUser?.uid ?? currentUid;
    final myEmail = currentUser?.email?.toLowerCase().trim() ?? '';

    try {
      final snap = await _db.collection('public_profiles').limit(50).get();
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['uid'] = doc.id;
        users.add(data);
      }
    } catch (e) {
      debugPrint('FriendService.fetchRegisteredUsers error: $e');
    }

    // Exclude current logged-in user strictly by UID, email, and handle:
    final filteredUsers = users.where((user) {
      final uUid = (user['uid'] ?? '').toString();
      final uEmail = (user['email'] ?? '').toString().toLowerCase().trim();
      if (myUid.isNotEmpty && uUid == myUid) return false;
      if (myEmail.isNotEmpty && uEmail == myEmail) return false;
      return true;
    }).toList();

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      return filteredUsers.where((user) {
        final name = (user['displayName'] ?? user['name'] ?? '').toString().toLowerCase();
        final handle = (user['handle'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final uid = (user['uid'] ?? '').toString().toLowerCase();
        return name.contains(q) || handle.contains(q) || email.contains(q) || uid.contains(q);
      }).toList();
    }

    return filteredUsers;
  }
}
