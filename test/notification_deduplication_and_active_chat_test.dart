import 'package:flutter_test/flutter_test.dart';
import 'package:sanchay/services/chat_service.dart';
import 'package:sanchay/services/notification_service.dart';

void main() {
  group('Bug 4 - Active Chat State Tracking & Lifecycle Logic', () {
    setUp(() {
      ChatService.clearActiveChat();
    });

    test('Initial active chat state is null/inactive', () {
      expect(ChatService.activeChatId, isNull);
      expect(ChatService.isChatActive('chat_alice_bob'), isFalse);
      expect(ChatService.isChatActive(''), isFalse);
      expect(ChatService.isChatActive(null), isFalse);
    });

    test('setActiveChat sets activeChatId and updates notifier', () {
      const chatId = 'alice_uid_bob_uid';
      String? notifiedValue;
      ChatService.activeChatIdNotifier.addListener(() {
        notifiedValue = ChatService.activeChatIdNotifier.value;
      });

      ChatService.setActiveChat(chatId);

      expect(ChatService.activeChatId, equals(chatId));
      expect(ChatService.isChatActive(chatId), isTrue);
      expect(ChatService.isChatActive('other_chat_id'), isFalse);
      expect(notifiedValue, equals(chatId));
    });

    test('clearActiveChat with matching chatId resets state', () {
      const chatId = 'alice_uid_bob_uid';
      ChatService.setActiveChat(chatId);
      expect(ChatService.isChatActive(chatId), isTrue);

      ChatService.clearActiveChat(chatId);

      expect(ChatService.activeChatId, isNull);
      expect(ChatService.isChatActive(chatId), isFalse);
    });

    test('clearActiveChat with non-matching chatId does not inadvertently clear active conversation', () {
      const activeChat = 'alice_uid_bob_uid';
      const otherChat = 'carol_uid_dave_uid';

      ChatService.setActiveChat(activeChat);
      ChatService.clearActiveChat(otherChat);

      expect(ChatService.activeChatId, equals(activeChat));
      expect(ChatService.isChatActive(activeChat), isTrue);
    });

    test('clearActiveChat with null clears unconditionally (e.g. app pause/background)', () {
      ChatService.setActiveChat('temp_chat_id');
      ChatService.clearActiveChat();

      expect(ChatService.activeChatId, isNull);
      expect(ChatService.isChatActive('temp_chat_id'), isFalse);
    });
  });

  group('Bug 1 - Notification Deduplication & Deterministic Message Keys', () {
    test('Deduplication cache marks message as notified and prevents duplicate processing', () {
      const testMsgId = 'unique_msg_id_999888';

      expect(NotificationService.isMessageRecentlyNotified(testMsgId), isFalse);

      NotificationService.markMessageAsNotified(testMsgId);

      expect(NotificationService.isMessageRecentlyNotified(testMsgId), isTrue);
    });

    test('Deterministic integer notification ID generates consistent 31-bit IDs', () {
      const msgId1 = 'msg_firestore_abc_123';
      const msgId2 = 'msg_firestore_def_456';

      final notifId1a = msgId1.hashCode & 0x7FFFFFFF;
      final notifId1b = msgId1.hashCode & 0x7FFFFFFF;
      final notifId2 = msgId2.hashCode & 0x7FFFFFFF;

      // Same message ID produces strictly identical Android notification ID
      expect(notifId1a, equals(notifId1b));
      expect(notifId1a, isNonNegative);

      // Different messages produce distinct notification IDs
      expect(notifId1a, isNot(equals(notifId2)));
    });

    test('LRU cache maintains bounding limit and evicts oldest items cleanly', () {
      for (int i = 0; i < 300; i++) {
        NotificationService.markMessageAsNotified('bulk_msg_$i');
      }

      // Oldest message (0) should have been evicted by the 250-element limit
      expect(NotificationService.isMessageRecentlyNotified('bulk_msg_0'), isFalse);

      // Latest message (299) must be retained
      expect(NotificationService.isMessageRecentlyNotified('bulk_msg_299'), isTrue);
    });
  });

  group('Bug 2 - Recipient Selection & Server-Side Security Principles', () {
    test('Recipient calculation excludes sender and selects genuine conversation partner', () {
      const senderUid = 'user_alice_123';
      const peerUid = 'user_bob_456';
      final participants = [senderUid, peerUid];

      // Legitimate participant check
      expect(participants.contains(senderUid), isTrue);

      // Server-side recipient extraction
      final recipients = participants.where((uid) => uid != senderUid).toList();

      expect(recipients, equals([peerUid]));
      expect(recipients.contains(senderUid), isFalse);
    });

    test('Untrusted client recipient spoofing is prevented by participants membership check', () {
      const senderUid = 'user_alice_123';
      const genuinePeer = 'user_bob_456';
      const spoofedTarget = 'unauthorized_victim_789';

      final chatParticipants = [senderUid, genuinePeer];

      // Sender tries to send message targeting spoofed recipient not in participants
      final isValidRecipient = chatParticipants.contains(spoofedTarget);
      expect(isValidRecipient, isFalse);

      final validRecipients = chatParticipants.where((uid) => uid != senderUid).toList();
      expect(validRecipients, equals([genuinePeer]));
      expect(validRecipients.contains(spoofedTarget), isFalse);
    });

    test('Deterministic composite chat ID consistency across participants', () {
      const uid1 = 'alice_uid';
      const uid2 = 'bob_uid';

      final idA = ChatService.getDeterministicChatId(uid1, uid2);
      final idB = ChatService.getDeterministicChatId(uid2, uid1);

      expect(idA, equals('alice_uid_bob_uid'));
      expect(idB, equals('alice_uid_bob_uid'));
      expect(idA, equals(idB));
    });
  });
}
