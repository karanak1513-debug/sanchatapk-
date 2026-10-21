import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import 'auth_service.dart';

import 'notification_parser.dart';
import 'sms_upi_parser_engine.dart';

class NotificationBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.aistudio.sanchay/notifications');
  static const EventChannel _eventChannel =
      EventChannel('com.aistudio.sanchay/notification_stream');

  static final NotificationBridge _instance = NotificationBridge._internal();
  factory NotificationBridge() => _instance;

  final _transactionStreamController = StreamController<Transaction>.broadcast();
  Stream<Transaction> get transactionStream => _transactionStreamController.stream;

  final Set<String> _recentDedupeKeys = {};
  bool _isListening = false;
  StreamSubscription? _eventSubscription;

  NotificationBridge._internal() {
    _initMethodChannelHandler();
    _initEventChannelHandler();
  }

  void _initMethodChannelHandler() {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationIntercepted') {
        try {
          final Map<dynamic, dynamic> rawMap = call.arguments as Map<dynamic, dynamic>;
          final map = Map<String, dynamic>.from(rawMap);
          _processIncomingPayload(map);
        } catch (e) {
          debugPrint('NotificationBridge MethodChannel error: $e');
        }
      }
    });
  }

  void _initEventChannelHandler() {
    if (kIsWeb || _isListening) return;

    try {
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final map = Map<String, dynamic>.from(event);
            _processIncomingPayload(map);
          }
        },
        onError: (dynamic error) {
          debugPrint('NotificationBridge EventChannel stream notice: $error');
        },
      );
      _isListening = true;
    } catch (e) {
      debugPrint('EventChannel listener setup notice: $e');
    }
  }

  void _processIncomingPayload(Map<String, dynamic> map) {
    try {
      final rawText = map['rawText'] as String?;
      ParsedFinancialSms? parsed;
      ParsedTransaction? upiParsed;
      if (rawText != null && rawText.isNotEmpty) {
        upiParsed = parseUpiMessage(rawText);
        parsed = SmsUpiParserEngine.parse(
          text: rawText,
          sender: map['source'] as String?,
        );
      }

      final amount = upiParsed?.amount ?? parsed?.amount ?? ((map['amount'] as num?)?.toDouble() ?? 0.0);
      final isCredit = upiParsed != null
          ? upiParsed.isCredit
          : (rawText != null && rawText.isNotEmpty
              ? NotificationParser.isCreditTransaction(rawText)
              : ((map['type'] as String?)?.toLowerCase() == 'credit' || (map['type'] as String?)?.toLowerCase() == 'income'));
      final type = isCredit ? 'income' : 'expense';
      final timestamp = map['timestamp'] is int
          ? (map['timestamp'] as int)
          : DateTime.now().millisecondsSinceEpoch;

      final minuteSlot = timestamp ~/ 60000;
      final dedupeKey = '${amount}_${type}_$minuteSlot';

      if (_recentDedupeKeys.contains(dedupeKey)) {
        debugPrint('Duplicate financial alert dropped by Dart bridge: $dedupeKey');
        return;
      }
      _recentDedupeKeys.add(dedupeKey);

      map['amount'] = amount;
      map['type'] = type;
      map['isAutoCaptured'] = true;
      map['channel'] = parsed?.channel ?? (map['channel'] ?? 'UPI');
      map['source'] = parsed?.source ?? (map['source'] ?? 'Auto Intercept');
      map['merchant'] = parsed?.merchant ?? (map['merchant'] ?? (upiParsed?.senderOrMerchant ?? (isCredit ? 'Received Payment' : 'Card / UPI Payment')));
      map['category'] = parsed?.category ?? (isCredit ? 'Received Payment' : (map['category'] ?? 'General'));
      map['tag'] = 'Auto UPI Intercept';
      if (parsed?.accountNumberLast4 != null) {
        map['accountNumber'] = parsed!.accountNumberLast4;
      }
      if (parsed?.referenceNumber != null) {
        map['referenceNumber'] = parsed!.referenceNumber;
      }
      if (parsed?.balanceAfter != null) {
        map['balanceAfter'] = parsed!.balanceAfter;
      }

      final tx = Transaction.fromJson(map);
      _transactionStreamController.add(tx);
      debugPrint('NotificationBridge: Dispatched live ${tx.channel} event -> ${tx.merchant} ₹${tx.amount}');

      // Direct Firestore injection in real-time
      final currentUid = AuthService().currentUserId;
      if (currentUid.isNotEmpty) {
        syncDirectToFirestore(tx, currentUid);
      }
    } catch (e) {
      debugPrint('Error parsing incoming notification payload: $e');
    }
  }

  // 1. Check if Notification Listener Permission is Active
  Future<bool> isPermissionGranted() async {
    if (kIsWeb) return false;
    try {
      final bool? granted =
          await _methodChannel.invokeMethod<bool>('isNotificationListenerGranted');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isNotificationAccessGranted() => isPermissionGranted();

  // 2. Deep-Link to Android Notification Listener Access Settings
  Future<void> openSettings() async {
    if (kIsWeb) return;
    try {
      await _methodChannel.invokeMethod('openNotificationListenerSettings');
    } catch (e) {
      debugPrint('Could not open notification settings: $e');
    }
  }

  Future<void> openNotificationSettings() => openSettings();

  // 3. Retrieve Pending Notifications Queued While App was Terminated
  Future<List<Transaction>> getPendingNotifications() async {
    if (kIsWeb) return [];
    try {
      final res = await _methodChannel.invokeMethod<List<dynamic>>('getPendingNotifications');
      if (res != null) {
        final currentUid = AuthService().currentUserId;
        final list = res.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final tx = Transaction.fromJson(map);
          if (currentUid.isNotEmpty) {
            syncDirectToFirestore(tx, currentUid);
          }
          return tx;
        }).toList();
        return list;
      }
    } catch (_) {}
    return [];
  }

  // 4. Directly Persist Intercepted Transaction to Firestore
  Future<void> syncDirectToFirestore(Transaction tx, String userId) async {
    if (userId.isEmpty) return;

    try {
      final docRef = AuthService.firestoreInstance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(tx.id);

      final payload = tx.toFirestore();
      payload['userId'] = userId;
      payload['isAutoCaptured'] = true;
      payload['channel'] = 'UPI';
      payload['tag'] = 'Auto UPI Intercept';
      payload['timestamp'] = FieldValue.serverTimestamp();

      await docRef.set(payload, SetOptions(merge: true));
      debugPrint('Directly persisted ${tx.merchant} to Firestore under users/$userId/transactions');
    } catch (e) {
      debugPrint('Error direct syncing to Firestore: $e');
    }
  }

  // 5. Test/Simulation Trigger
  Future<void> simulateNotification({
    required String merchant,
    required double amount,
    required String type,
    required String source,
    String? category,
    String? channel,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final txMap = {
      'id': 'sim_$now',
      'merchant': merchant,
      'amount': amount,
      'type': type,
      'source': source,
      'channel': channel ?? (source.contains('ATM') ? 'CASH' : 'UPI'),
      'category': category ?? 'General',
      'tag': 'Auto-Intercepted',
      'isAutoCaptured': true,
      'timestamp': now,
    };

    if (kIsWeb) {
      _processIncomingPayload(txMap);
      return;
    }

    try {
      await _methodChannel.invokeMethod('simulateNotification', txMap);
    } catch (_) {
      _processIncomingPayload(txMap);
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
  }
}
