import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/transaction.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'fcm_service.dart';

class NotificationService {
  static const MethodChannel _channel =
      MethodChannel('com.aistudio.sanchay/notifications');

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  FlutterLocalNotificationsPlugin get localNotifications => _localNotifications;

  bool _isInitialized = false;

  // Deduplication cache for chat message notifications
  static final Set<String> _recentlyNotifiedMessageIds = <String>{};
  static final List<String> _notifiedMessageIdOrder = <String>[];
  static const int _maxDeduplicationCacheSize = 250;

  static bool isMessageRecentlyNotified(String messageId) {
    return _recentlyNotifiedMessageIds.contains(messageId);
  }

  static void markMessageAsNotified(String messageId) {
    if (_recentlyNotifiedMessageIds.contains(messageId)) return;
    if (_notifiedMessageIdOrder.length >= _maxDeduplicationCacheSize) {
      final oldest = _notifiedMessageIdOrder.removeAt(0);
      _recentlyNotifiedMessageIds.remove(oldest);
    }
    _recentlyNotifiedMessageIds.add(messageId);
    _notifiedMessageIdOrder.add(messageId);
  }

  NotificationService._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final _transactionStreamController =
      StreamController<Transaction>.broadcast();
  Stream<Transaction> get transactionStream =>
      _transactionStreamController.stream;

  // Initialize both local notification system & timezone database
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      try {
        tz.initializeTimeZones();
      } catch (e) {
        debugPrint('Timezone initialization note: $e');
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      try {
        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (details) {
            debugPrint('Notification clicked: ${details.payload}');
            if (details.payload != null && details.payload!.isNotEmpty) {
              FcmService().handleNotificationPayload(details.payload!);
            }
          },
        );

        // Request Android 13+ Notification Permission & Android 14/15/16 Exact Alarms Permission
        final androidImpl = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.requestNotificationsPermission();
          await androidImpl.requestExactAlarmsPermission();

          // Explicitly create notification channels for foreground & heads-up display
          const socialChannel = AndroidNotificationChannel(
            'sanchay_social_alerts',
            'Sanchat Social & Messages',
            description: 'Real-time notifications for friend requests and 1-on-1 chats',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );
          await androidImpl.createNotificationChannel(socialChannel);

          const reminderChannel = AndroidNotificationChannel(
            'sanchay_daily_reminders',
            'Sanchat Daily Goal Reminders',
            description: 'Notifications for tracking daily savings pace and quota fulfillment',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );
          await androidImpl.createNotificationChannel(reminderChannel);
        }

        // Verify & Prompt Alarms & Reminders permission via permission_handler
        await checkAndRequestExactAlarmPermission();
      } catch (e) {
        debugPrint('Local notifications init note: $e');
      }
    }

    _isInitialized = true;
  }

  // 1. Android Notification Channels configuration
  static const String _channelId = 'sanchay_daily_reminders';
  static const String _channelName = 'Sanchay Daily Goal Reminders';
  static const String _channelDesc =
      'Notifications for tracking daily savings pace and quota fulfillment';

  NotificationDetails _buildNotificationDetails({bool isUrgent = true}) {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: isUrgent ? Importance.max : Importance.defaultImportance,
      priority: isUrgent ? Priority.high : Priority.defaultPriority,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      color: const Color(0xFFDC2626), // Sanchay Crimson
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(android: androidDetails, iOS: darwinDetails);
  }

  // 2. Schedule Recurring Daily Reminder at designated Time (Default: 21:00)
  Future<void> scheduleDailyGoalReminder({
    required TimeOfDay time,
    required double todaySaved,
    required double dailyPaceTarget,
  }) async {
    await initialize();
    if (kIsWeb) return;

    final isTargetMet = todaySaved >= dailyPaceTarget && dailyPaceTarget > 0;
    final shortfall = (dailyPaceTarget - todaySaved).clamp(0.0, double.infinity);

    final String title;
    final String body;

    if (isTargetMet) {
      title = 'Sanchay — Daily Target Hit 🔥';
      body =
          'You saved ₹${todaySaved.toStringAsFixed(0)} today. Your daily pace is complete!';
    } else {
      title = 'Sanchay — Daily Quota Incomplete ⏳';
      body =
          '₹${shortfall.toStringAsFixed(0)} remaining before midnight reset to maintain your reserve target pace.';
    }

    try {
      // Cancel previous scheduled reminder
      await _localNotifications.cancel(1001);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // If scheduled time has already passed today, advance to next day
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _localNotifications.zonedSchedule(
        1001,
        title,
        body,
        scheduledDate,
        _buildNotificationDetails(isUrgent: !isTargetMet),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint(
        'Daily goal reminder scheduled for ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('Failed to schedule daily notification: $e');
    }
  }

  // 3. Cancel Scheduled Notifications
  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    try {
      await _localNotifications.cancel(1001);
      await _localNotifications.cancel(101);
      debugPrint('Cancelled scheduled daily goal reminders');
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  // 4. Exact 24-Hour Daily Target Closing Push Notification (Android 16 Safe)
  Future<void> scheduleDailyClosingNotification({
    String? title,
    String? body,
  }) async {
    await initialize();
    if (kIsWeb) return;

    try {
      final now = tz.TZDateTime.now(tz.local);
      final midnight = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        0,
        0,
      );
      final remainingDurationToMidnight = midnight.difference(now);
      final tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local).add(remainingDurationToMidnight);

      await _localNotifications.cancel(101);

      await _localNotifications.zonedSchedule(
        101,
        title ?? 'Sanchay — Daily Target Closing',
        body ?? 'Your daily goal is active. Check your remaining quota before midnight.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'sanchay_daily_reminders',
            'Daily Discipline Reminders',
            channelDescription: 'Exact scheduled reminders for daily wealth target',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('Daily target closing exact alarm scheduled for: $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling daily target closing notification: $e');
    }
  }

  // 5. Prompt user to grant "Alarms & Reminders" permission via permission_handler (Android 14/15/16)
  Future<bool> checkAndRequestExactAlarmPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.scheduleExactAlarm.status;
      if (!status.isGranted) {
        final result = await Permission.scheduleExactAlarm.request();
        return result.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('scheduleExactAlarm permission check note: $e');
      return false;
    }
  }

  // 4. Instant Test Push Notification Trigger
  Future<void> triggerInstantTestPush({
    required double todaySaved,
    required double dailyPaceTarget,
  }) async {
    await initialize();

    final isTargetMet = todaySaved >= dailyPaceTarget && dailyPaceTarget > 0;
    final shortfall = (dailyPaceTarget - todaySaved).clamp(0.0, double.infinity);

    final String title = isTargetMet
        ? 'Sanchay — Daily Target Hit 🔥'
        : 'Sanchay — Daily Quota Incomplete ⏳';

    final String body = isTargetMet
        ? 'You saved ₹${todaySaved.toStringAsFixed(0)} today. Your daily pace is complete!'
        : '₹${shortfall > 0 ? shortfall.toStringAsFixed(0) : "0"} remaining before midnight reset to maintain your reserve target pace.';

    if (!kIsWeb) {
      try {
        await _localNotifications.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          _buildNotificationDetails(isUrgent: !isTargetMet),
        );
      } catch (e) {
        debugPrint('Could not display native notification: $e');
      }
    } else {
      debugPrint('[Web Push Simulation] $title: $body');
    }
  }

  // 4b. Incoming Friend Request & Chat Message Notification Triggers
  Future<void> showFriendRequestNotification({
    required String senderName,
    required String senderHandle,
  }) async {
    await initialize();
    final title = 'New Friend Request 🔔';
    final body = '$senderName ($senderHandle) wants to connect on Sanchay.';

    if (!kIsWeb) {
      try {
        const androidDetails = AndroidNotificationDetails(
          'sanchay_social_alerts',
          'Sanchay Social & Messages',
          channelDescription: 'Real-time notifications for friend requests and 1-on-1 chats',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          color: Color(0xFF0F172A),
          icon: '@mipmap/ic_launcher',
        );
        const darwinDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        await _localNotifications.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          const NotificationDetails(android: androidDetails, iOS: darwinDetails),
        );
      } catch (e) {
        debugPrint('Error showing friend request notification: $e');
      }
    } else {
      debugPrint('[Web Push] $title: $body');
    }
  }

  Future<void> showChatMessageNotification({
    required String senderName,
    required String messageText,
    String? chatId,
    String? messageId,
    String? senderId,
  }) async {
    await initialize();

    // 1. Never send/display notification to sender for their own message
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUserId;
    if (currentUid.isNotEmpty && senderId != null && senderId == currentUid) {
      debugPrint('Suppressed notification: sender is current user');
      return;
    }

    // 2. Do not show notification when recipient is actively viewing this same conversation
    if (chatId != null && ChatService.isChatActive(chatId)) {
      debugPrint('Suppressed notification: user is actively viewing chat $chatId');
      return;
    }

    // 3. Stable message ID deduplication: ensure each message triggers at most one notification
    if (messageId != null && messageId.isNotEmpty) {
      if (_recentlyNotifiedMessageIds.contains(messageId)) {
        debugPrint('Suppressed duplicate notification for messageId: $messageId');
        return;
      }
      markMessageAsNotified(messageId);
    }

    final title = senderName;
    final body = messageText;

    if (!kIsWeb) {
      try {
        const androidDetails = AndroidNotificationDetails(
          'sanchay_social_alerts',
          'Sanchat Social & Messages',
          channelDescription: 'Real-time notifications for friend requests and 1-on-1 chats',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          color: Color(0xFF0F172A),
          icon: '@mipmap/ic_launcher',
        );
        const darwinDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        // Deterministic integer notification ID based on stable message/chat ID
        final int notificationId = (messageId != null && messageId.isNotEmpty)
            ? (messageId.hashCode & 0x7FFFFFFF)
            : (chatId != null && chatId.isNotEmpty
                ? (chatId.hashCode & 0x7FFFFFFF)
                : 1002);

        final payload = jsonEncode({
          'type': 'chat_message',
          'chatId': chatId ?? '',
          'senderId': senderId ?? '',
          'messageId': messageId ?? '',
        });

        await _localNotifications.show(
          notificationId,
          title,
          body,
          const NotificationDetails(android: androidDetails, iOS: darwinDetails),
          payload: payload,
        );
      } catch (e) {
        debugPrint('Error showing chat message notification: $e');
      }
    } else {
      debugPrint('[Web Push] $title: $body');
    }
  }

  // 5. Native UPI Platform Channel Handlers
  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onNotificationIntercepted') {
      try {
        final Map<dynamic, dynamic> rawMap = call.arguments as Map<dynamic, dynamic>;
        final map = Map<String, dynamic>.from(rawMap);
        final tx = Transaction.fromJson(map);
        _transactionStreamController.add(tx);
        debugPrint('Flutter received intercepted transaction: ${tx.merchant} ₹${tx.amount}');
      } catch (e) {
        debugPrint('Error parsing native intercepted notification: $e');
      }
    }
  }

  Future<bool> isNotificationListenerGranted() async {
    if (kIsWeb) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isNotificationListenerGranted');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openNotificationListenerSettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } catch (e) {
      debugPrint('Could not open notification settings: $e');
    }
  }

  Future<List<Transaction>> getPendingNotifications() async {
    if (kIsWeb) return [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getPendingNotifications');
      if (res != null) {
        return res.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return Transaction.fromJson(map);
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> simulateNotification({
    required String merchant,
    required double amount,
    required String type,
    required String source,
    String? category,
  }) async {
    final txMap = {
      'id': 'sim_${DateTime.now().millisecondsSinceEpoch}',
      'merchant': merchant,
      'amount': amount,
      'type': type,
      'source': source,
      'category': category ?? 'General',
      'tag': 'Live Intercepted',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (kIsWeb) {
      final tx = Transaction.fromJson(txMap);
      _transactionStreamController.add(tx);
      return;
    }

    try {
      await _channel.invokeMethod('simulateNotification', txMap);
    } catch (_) {
      final tx = Transaction.fromJson(txMap);
      _transactionStreamController.add(tx);
    }
  }
}
