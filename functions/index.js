/**
 * Sanchat - Production Chat Push Notification Cloud Function
 *
 * Listens for new messages in Cloud Firestore at:
 *   chats/{chatId}/messages/{messageId}
 * Validates participant permissions, determines recipients server-side,
 * fetches FCM tokens, performs idempotency checks, and sends push notifications
 * via Firebase Admin SDK.
 */

const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

// Initialize Firebase Admin SDK
admin.initializeApp();

const DATABASE_ID = "ai-studio-android-sanchay-c9654c5d-c4ca-4c5c-8b5e-20b5665d1fcb";
const db = getFirestore(DATABASE_ID);

/**
 * Sanitize preview text to ensure zero leakage of private banking / financial transactions
 */
function createSafeMessagePreview(rawText) {
  if (!rawText || typeof rawText !== "string") {
    return "New message";
  }

  const trimmed = rawText.trim();
  if (trimmed.length === 0) {
    return "New message";
  }

  // Privacy guard: Never leak financial, OTP, or sensitive card/account numbers in push previews
  const sensitivePatterns = [
    /\b\d{4,6}\b.*otp/i,
    /otp.*\b\d{4,6}\b/i,
    /credited|debited|a\/c|acct|balance|bank|inr|rs\.?\s*\d+/i,
    /vpa|upi\s*ref|rrn\b/i,
  ];

  for (const pattern of sensitivePatterns) {
    if (pattern.test(trimmed)) {
      return "New secure financial update";
    }
  }

  // Safe truncated preview (max 100 chars)
  if (trimmed.length > 100) {
    return trimmed.substring(0, 97) + "...";
  }
  return trimmed;
}

/**
 * Main Cloud Function trigger on message creation
 */
exports.onChatMessageCreated = onDocumentCreated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    database: DATABASE_ID,
    region: "asia-southeast1",
    maxInstances: 10,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      return;
    }

    const messageData = snap.data();
    if (!messageData) {
      return;
    }

    const { chatId, messageId } = event.params;
    const senderId = messageData.senderId;

    if (!senderId || !chatId || !messageId) {
      console.warn(`[onChatMessageCreated] Missing required routing fields in message ${messageId}`);
      return;
    }

    // Skip messages that were soft-deleted, already flagged as processed, or draft/failed
    if (messageData.isDeleted === true || messageData.status === "failed") {
      return;
    }

    // 1. Idempotency Check: Prevent duplicate push notifications on function retry
    const deliveryMarkerRef = db
      .collection("chats")
      .doc(chatId)
      .collection("messages")
      .doc(messageId)
      .collection("delivery_metadata")
      .doc("push");

    try {
      const markerSnap = await deliveryMarkerRef.get();
      if (markerSnap.exists && markerSnap.data()?.completed === true) {
        console.log(`[onChatMessageCreated] Message ${messageId} push already processed. Skipping.`);
        return;
      }
    } catch (e) {
      console.warn(`[onChatMessageCreated] Idempotency marker check warning: ${e.message}`);
    }

    try {
      // 2. Read trusted parent chat document to verify participants server-side
      const chatDoc = await db.collection("chats").doc(chatId).get();
      if (!chatDoc.exists) {
        console.warn(`[onChatMessageCreated] Parent chat ${chatId} not found`);
        return;
      }

      const chatData = chatDoc.data() || {};
      const participants = Array.isArray(chatData.participants)
        ? chatData.participants.map(String)
        : [];

      // Validate that sender is indeed a legitimate participant in this chat
      if (!participants.includes(senderId)) {
        console.warn(`[onChatMessageCreated] Sender ${senderId} is not a member of chat ${chatId}. Aborting.`);
        return;
      }

      // Determine recipient(s) server-side (exclude the sender)
      const recipientIds = participants.filter((uid) => uid !== senderId);
      if (recipientIds.length === 0) {
        console.log(`[onChatMessageCreated] No recipients to notify for chat ${chatId}`);
        return;
      }

      // 3. Fetch Sender Display Name for the notification title
      let senderDisplayName = "Sanchat";
      try {
        const publicProfileDoc = await db.collection("public_profiles").doc(senderId).get();
        if (publicProfileDoc.exists) {
          senderDisplayName = publicProfileDoc.data()?.displayName || senderDisplayName;
        } else {
          const userDoc = await db.collection("users").doc(senderId).get();
          if (userDoc.exists) {
            senderDisplayName = userDoc.data()?.displayName || userDoc.data()?.name || senderDisplayName;
          }
        }
      } catch (e) {
        console.warn(`[onChatMessageCreated] Could not fetch profile for sender ${senderId}: ${e.message}`);
      }

      const notificationTitle = senderDisplayName;
      const notificationBody = createSafeMessagePreview(messageData.text);

      // 4. Process each recipient
      for (const recipientId of recipientIds) {
        // Check recipient block/mute settings if configured
        try {
          const recipientDoc = await db.collection("users").doc(recipientId).get();
          if (recipientDoc.exists) {
            const recipientData = recipientDoc.data() || {};
            const blockedUsers = recipientData.blockedUsers || [];
            if (Array.isArray(blockedUsers) && blockedUsers.includes(senderId)) {
              console.log(`[onChatMessageCreated] Recipient ${recipientId} has blocked sender ${senderId}. Skipping.`);
              continue;
            }

            // Check chat-specific mute
            const mutedChats = recipientData.mutedChats || [];
            if (Array.isArray(mutedChats) && mutedChats.includes(chatId)) {
              console.log(`[onChatMessageCreated] Chat ${chatId} is muted by recipient ${recipientId}. Skipping.`);
              continue;
            }
          }
        } catch (e) {
          console.warn(`[onChatMessageCreated] Recipient settings check note: ${e.message}`);
        }

        // 5. Fetch recipient's active FCM tokens
        const tokens = new Set();

        // Check fcm_tokens subcollection
        try {
          const tokensSnap = await db
            .collection("users")
            .doc(recipientId)
            .collection("fcm_tokens")
            .get();

          for (const doc of tokensSnap.docs) {
            const tokenVal = doc.data()?.token;
            if (tokenVal && typeof tokenVal === "string" && tokenVal.trim().length > 0) {
              tokens.add(tokenVal.trim());
            }
          }
        } catch (e) {
          console.warn(`[onChatMessageCreated] fcm_tokens subcollection read error: ${e.message}`);
        }

        // Check fallback array in root user doc
        try {
          const userDoc = await db.collection("users").doc(recipientId).get();
          if (userDoc.exists) {
            const userData = userDoc.data() || {};
            if (Array.isArray(userData.fcmTokens)) {
              for (const t of userData.fcmTokens) {
                if (t && typeof t === "string") tokens.add(t.trim());
              }
            }
            if (userData.lastFcmToken && typeof userData.lastFcmToken === "string") {
              tokens.add(userData.lastFcmToken.trim());
            }
          }
        } catch (e) {
          console.warn(`[onChatMessageCreated] user doc token check error: ${e.message}`);
        }

        const validTokens = Array.from(tokens);
        if (validTokens.length === 0) {
          console.log(`[onChatMessageCreated] No active FCM tokens found for recipient ${recipientId}`);
          continue;
        }

        // 6. Build High-Priority Android & iOS Push Payload
        const messagePayload = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            type: "chat_message",
            chatId: String(chatId),
            messageId: String(messageId),
            senderId: String(senderId),
            senderName: String(notificationTitle),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "sanchay_social_alerts",
              icon: "ic_launcher",
              color: "#0F172A",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              sound: "default",
              tag: `chat_${chatId}`,
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
                contentAvailable: true,
              },
            },
          },
          tokens: validTokens,
        };

        // 7. Send Multicast via Firebase Admin SDK
        const response = await admin.messaging().sendEachForMulticast(messagePayload);
        console.log(
          `[onChatMessageCreated] FCM multicast sent to recipient ${recipientId}: ` +
          `${response.successCount} succeeded, ${response.failureCount} failed out of ${validTokens.length} tokens.`
        );

        // 8. Stale & Invalid Token Cleanup
        if (response.failureCount > 0) {
          const tokensToRemove = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const errCode = resp.error?.code;
              if (
                errCode === "messaging/invalid-registration-token" ||
                errCode === "messaging/registration-token-not-registered"
              ) {
                tokensToRemove.push(validTokens[idx]);
              }
            }
          });

          for (const staleToken of tokensToRemove) {
            try {
              const safeDocId = staleToken.replace(/[^a-zA-Z0-9_-]/g, "_");
              await db
                .collection("users")
                .doc(recipientId)
                .collection("fcm_tokens")
                .doc(safeDocId)
                .delete();

              await db.collection("users").doc(recipientId).update({
                fcmTokens: FieldValue.arrayRemove([staleToken]),
              });
              console.log(`[onChatMessageCreated] Pruned stale FCM token for user ${recipientId}`);
            } catch (err) {
              console.warn(`[onChatMessageCreated] Error pruning stale token: ${err.message}`);
            }
          }
        }
      }

      // 9. Write Idempotency Marker to guarantee single execution
      await deliveryMarkerRef.set(
        {
          completed: true,
          deliveredAt: FieldValue.serverTimestamp(),
          recipientCount: recipientIds.length,
        },
        { merge: true }
      );
    } catch (error) {
      console.error(`[onChatMessageCreated] Fatal error processing message ${messageId}:`, error);
    }
  }
);
