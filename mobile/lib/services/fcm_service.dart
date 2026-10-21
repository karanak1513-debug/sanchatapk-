import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import '../screens/chat_conversation_screen.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'notification_service.dart';

/// Top-level background message handler required by FirebaseMessaging.
/// Must be annotated with @pragma('vm:entry-point') and placed at top level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
  debugPrint('FCM background message received: ${message.messageId}');
  // System tray automatically displays notifications when notification payload is provided.
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static FirebaseFirestore get _db => AuthService.firestoreInstance;

  bool _isInitialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<User?>? _authSub;

  /// Global navigator key for notification tap navigation
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Pending navigation target if notification was tapped while app was initializing or unauthenticated
  static Map<String, dynamic>? pendingNotificationTarget;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;

    try {
      // 1. Request notification permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM authorization status: ${settings.authorizationStatus}');

      // 2. Register top-level background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Configure foreground presentation options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Register current device token for authenticated user
      await registerCurrentDeviceToken();

      // 5. Automatically re-register token whenever authentication state changes
      _authSub?.cancel();
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          registerCurrentDeviceToken();
          // Attempt pending notification navigation once user session is ready
          checkAndNavigatePendingInitialMessage();
        }
      });

      // 6. Listen for token refresh events
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _saveTokenToFirestore(newToken);
      });

      // 7. Foreground message listener with active-chat & duplicate suppression
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground message received: ${message.messageId}');
        final data = message.data;
        final type = data['type'] as String? ?? 'chat_message';
        final chatId = data['chatId'] as String? ?? '';
        final senderId = data['senderId'] as String? ?? '';
        final messageId = data['messageId'] as String? ?? message.messageId;

        // A. Suppress if sender is me
        final myUid =
            FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
        if (myUid.isNotEmpty && senderId.isNotEmpty && senderId == myUid) {
          debugPrint('Suppressing foreground notification: sender is current user');
          return;
        }

        // B. Suppress if recipient is actively viewing this exact conversation
        if (chatId.isNotEmpty && ChatService.isChatActive(chatId)) {
          debugPrint(
              'Suppressing foreground notification: chat $chatId is currently active');
          return;
        }

        // C. Display single local notification for chat message
        if (type == 'chat' || type == 'chat_message') {
          final title = message.notification?.title ??
              data['senderName'] as String? ??
              'New message';
          final body = message.notification?.body ??
              data['text'] as String? ??
              data['preview'] as String? ??
              'You have a new message';

          NotificationService().showChatMessageNotification(
            senderName: title,
            messageText: body,
            chatId: chatId,
            messageId: messageId,
            senderId: senderId,
          );
        }
      });

      // 8. Background notification tap handling (app resumed from background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification opened from background: ${message.data}');
        handleNotificationData(message.data);
      });

      // 9. Cold-start notification check (app launched from terminated state)
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Cold-start FCM initial message found: ${initialMessage.data}');
        pendingNotificationTarget = initialMessage.data;
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('FcmService initialization error: $e');
    }
  }

  /// Handles incoming JSON payload from local notification click
  void handleNotificationPayload(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        handleNotificationData(decoded);
      } else if (rawPayload.isNotEmpty) {
        handleNotificationData({'chatId': rawPayload, 'type': 'chat_message'});
      }
    } catch (e) {
      // Fallback if payload is plain string chatId
      if (rawPayload.isNotEmpty) {
        handleNotificationData({'chatId': rawPayload, 'type': 'chat_message'});
      }
    }
  }

  /// Dispatches notification payload data to appropriate screen navigation
  void handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'chat_message';
    final chatId = data['chatId'] as String?;
    final senderId = data['senderId'] as String?;

    if ((type == 'chat' || type == 'chat_message') &&
        (chatId != null || senderId != null)) {
      final navContext = navigatorKey.currentContext;
      final currentUid =
          FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;

      if (navContext == null || currentUid.isEmpty) {
        // Queue target for resolution after auth & UI build
        pendingNotificationTarget = data;
        debugPrint('Queued pending notification navigation for chat: $chatId');
        return;
      }

      _navigateToConversation(navContext, chatId: chatId, senderId: senderId);
    }
  }

  /// Consumes and executes any pending cold-start notification navigation
  void checkAndNavigatePendingInitialMessage([BuildContext? context]) {
    final target = pendingNotificationTarget;
    if (target == null) return;

    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
    if (currentUid.isEmpty) {
      // Still awaiting auth resolution
      return;
    }

    final targetContext = context ?? navigatorKey.currentContext;
    if (targetContext == null) return;

    pendingNotificationTarget = null;
    final chatId = target['chatId'] as String?;
    final senderId = target['senderId'] as String?;

    _navigateToConversation(targetContext, chatId: chatId, senderId: senderId);
  }

  void _navigateToConversation(
    BuildContext context, {
    String? chatId,
    String? senderId,
  }) {
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;

    String peerUid = senderId ?? '';
    if (peerUid.isEmpty && chatId != null && chatId.contains('_')) {
      final parts = chatId.split('_');
      if (parts.length == 2) {
        peerUid = parts[0] == currentUid ? parts[1] : parts[0];
      }
    }

    if (peerUid.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            peerUid: peerUid,
            chatId: chatId,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushNamed('/chat');
    }
  }

  /// Register current device's FCM token under authenticated user document
  Future<void> registerCurrentDeviceToken({String? explicitUid}) async {
    final uid = explicitUid ??
        FirebaseAuth.instance.currentUser?.uid ??
        AuthService().currentUserId;
    if (uid.isEmpty) return;

    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveTokenToFirestore(token, uid: uid);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token, {String? uid}) async {
    final effectiveUid = uid ??
        FirebaseAuth.instance.currentUser?.uid ??
        AuthService().currentUserId;
    if (effectiveUid.isEmpty) return;

    try {
      final safeDocId = token.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final tokenRef = _db
          .collection('users')
          .doc(effectiveUid)
          .collection('fcm_tokens')
          .doc(safeDocId);

      await tokenRef.set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also maintain array and last token on user root doc for quick resolution
      await _db.collection('users').doc(effectiveUid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastFcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('FCM Token successfully stored for user $effectiveUid');
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }

  /// Unregister FCM token on logout to ensure no notification leaks across accounts
  Future<void> unregisterTokenOnLogout({String? explicitUid}) async {
    final uid = explicitUid ??
        FirebaseAuth.instance.currentUser?.uid ??
        AuthService().currentUserId;
    if (uid.isEmpty) return;

    try {
      final token = await _fcm.getToken();
      if (token != null) {
        final safeDocId = token.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final tokenRef = _db
            .collection('users')
            .doc(uid)
            .collection('fcm_tokens')
            .doc(safeDocId);

        await tokenRef.delete();
        await _db.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
        debugPrint('FCM Token removed for user $uid on logout');
      }
    } catch (e) {
      debugPrint('Error removing FCM token on logout: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _authSub?.cancel();
  }
}
