import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/models/chat_message.dart';
import 'package:sanchay/models/chat_user.dart';
import 'package:sanchay/screens/chat_conversation_screen.dart';
import 'package:sanchay/services/chat_service.dart';
import 'package:sanchay/widgets/message_status_tick.dart';

void main() {
  group('1-on-1 Chat Architecture & Deterministic Composite Keys', () {
    test('getChatId returns alphabetical composite key regardless of sender/receiver order', () {
      final chatService = ChatService();

      const uidA = 'alice_uid_123';
      const uidB = 'bob_uid_456';

      final chatId1 = chatService.getChatId(uidB, uidA);
      final chatId2 = chatService.getChatId(uidA, uidB);

      expect(chatId1, equals('alice_uid_123_bob_uid_456'));
      expect(chatId2, equals('alice_uid_123_bob_uid_456'));
      expect(chatId1, equals(chatId2));
    });

    test('normalizeUsername properly sanitizes handles and emails to lowercase alphanumeric', () {
      expect(ChatService.normalizeUsername('@Alice_Bob123'), equals('alice_bob123'));
      expect(ChatService.normalizeUsername('Karan.Wealth!'), equals('karanwealth'));
      expect(ChatService.normalizeUsername('@SanchayUser'), equals('sanchayuser'));
    });

    test('ChatUser model creates normalized fields, initials, handle, and uidSnippet', () {
      final user = ChatUser(
        uid: 'user_8f2a9910bcd',
        displayName: 'Aarav Patel',
        username: 'aarav_p',
        email: 'aarav.patel@sanchay.app',
      );

      expect(user.displayName, equals('Aarav Patel'));
      expect(user.username, equals('aarav_p'));
      expect(user.handle, equals('@aarav_p'));
      expect(user.initials, equals('AP'));
      expect(user.uidSnippet, equals('user_8f2'));
    });

    test('ChatMessage serializes and deserializes correctly with delivery statuses', () {
      final now = DateTime(2026, 10, 6, 22, 14);
      final message = ChatMessage(
        id: 'msg_001',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Hello, testing real-time Sanchay chat!',
        timestamp: now,
        status: 'sent',
      );

      expect(message.isSentByMe('user_a'), isTrue);
      expect(message.isSentByMe('user_b'), isFalse);
      expect(message.isSending, isFalse);
      expect(message.isSent, isTrue);
      expect(message.isDelivered, isFalse);
      expect(message.isSeen, isFalse);
      expect(message.status, equals('sent'));

      final map = message.toMap();
      expect(map['text'], equals('Hello, testing real-time Sanchay chat!'));
      expect(map['status'], equals('sent'));

      final restored = ChatMessage.fromMap({
        'senderId': 'user_a',
        'receiverId': 'user_b',
        'text': 'Hello, testing real-time Sanchay chat!',
        'timestamp': now.millisecondsSinceEpoch,
        'status': 'delivered',
      }, 'msg_001');

      expect(restored.status, equals('delivered'));
      expect(restored.isDelivered, isTrue);
      expect(restored.id, equals('msg_001'));
    });

    test('ChatRoom calculates unread counts and peer UID correctly', () {
      final room = ChatRoom(
        chatId: 'alice_bob',
        participants: ['alice', 'bob'],
        lastMessage: 'Let us hit our savings goal',
        lastTimestamp: DateTime.now(),
        unreadCount: {'alice': 0, 'bob': 3},
      );

      expect(room.getPeerUid('alice'), equals('bob'));
      expect(room.getPeerUid('bob'), equals('alice'));
      expect(room.getUnreadFor('bob'), equals(3));
      expect(room.getUnreadFor('alice'), equals(0));
    });
  });

  group('MessageStatusTick UI Component Tests', () {
    testWidgets('Renders single grey check for status == sent', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageStatusTick(status: 'sent'),
          ),
        ),
      );

      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsOneWidget);

      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.icon, equals(Icons.check));
      expect(icon.color, equals(Colors.grey));
    });

    testWidgets('Renders double grey check for status == delivered', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageStatusTick(status: 'delivered'),
          ),
        ),
      );

      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsOneWidget);

      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.icon, equals(Icons.done_all));
      expect(icon.color, equals(Colors.grey));
    });

    testWidgets('Renders double blue check for status == seen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageStatusTick(status: 'seen'),
          ),
        ),
      );

      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsOneWidget);

      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.icon, equals(Icons.done_all));
      expect(icon.color, equals(const Color(0xFF0284C7)));
    });

    testWidgets('Renders clock icon for status == sending', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageStatusTick(status: 'sending'),
          ),
        ),
      );

      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsOneWidget);

      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.icon, equals(Icons.access_time_rounded));
    });
  });

  group('ChatConversationScreen Widget Tests', () {
    testWidgets('Renders Swiss porcelain chat screen with app bar and composer', (WidgetTester tester) async {
      final peer = ChatUser(
        uid: 'peer_123',
        displayName: 'Rohan Sharma',
        username: 'rohansharma',
        email: 'rohan@example.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationScreen(
            peerUid: peer.uid,
            peerName: peer.displayName,
            peer: peer,
          ),
        ),
      );

      // Verify Peer Name is displayed in App Bar
      expect(find.text('Rohan Sharma'), findsOneWidget);

      // Verify composer hint text
      expect(find.text('Type a message...'), findsOneWidget);

      // Verify send arrow icon exists
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });
  });
}
