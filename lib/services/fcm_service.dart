import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'notification_service.dart';

/// Top-level background message handler required by FirebaseMessaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId}');
  // Background notifications with a notification payload are handled automatically by the system tray
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static FirebaseFirestore get _db => AuthService.firestoreInstance;

  bool _isInitialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Global navigator key for notification tap navigation
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Register foreground presentation options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Handle initial token registration
      await registerCurrentDeviceToken();

      // 5. Listen for token refresh events
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _saveTokenToFirestore(newToken);
      });

      // 6. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground message received: ${message.notification?.title}');
        final notification = message.notification;
        final data = message.data;

        if (notification != null) {
          final type = data['type'] ?? 'chat';
          final chatId = data['chatId'] ?? '';
          final title = notification.title ?? 'New message';
          final body = notification.body ?? 'You have a new message';

          if (type == 'chat') {
            NotificationService().showChatMessageNotification(
              senderName: title,
              messageText: body,
              chatId: chatId,
            );
          }
        }
      });

      // 7. Notification tap handling (when app is in background or opened from terminated state)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message.data);
      });

      // Check if opened from terminated state
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('FcmService initialization error: $e');
    }
  }

  /// Register current device's FCM token under authenticated user document
  Future<void> registerCurrentDeviceToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
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
    final effectiveUid = uid ?? FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
    if (effectiveUid.isEmpty) return;

    try {
      final tokenRef = _db
          .collection('users')
          .doc(effectiveUid)
          .collection('fcm_tokens')
          .doc(token.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_'));

      await tokenRef.set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also maintain array for simple lookup
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

  /// Unregister FCM token on logout
  Future<void> unregisterTokenOnLogout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
    if (uid.isEmpty) return;

    try {
      final token = await _fcm.getToken();
      if (token != null) {
        final tokenRef = _db
            .collection('users')
            .doc(uid)
            .collection('fcm_tokens')
            .doc(token.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_'));

        await tokenRef.delete();
        await _db.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (e) {
      debugPrint('Error removing FCM token on logout: $e');
    }
  }

  /// Handle notification tap navigation
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final chatId = data['chatId'] as String?;
    final senderId = data['senderId'] as String?;

    if (type == 'chat' && (chatId != null || senderId != null)) {
      final navContext = navigatorKey.currentContext;
      if (navContext != null) {
        Navigator.of(navContext).pushNamed(
          '/chat',
        );
      }
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
  }
}
