import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart';
import '../models/sanchay_target.dart';
import '../models/transaction.dart';
import 'auth_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  FirestoreService._internal() {
    _enableOfflinePersistence();
  }

  FirebaseFirestore get _firestore => AuthService.firestoreInstance;

  void _enableOfflinePersistence() {
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore offline persistence configuration notice: $e');
    }
  }

  // =========================================================================
  // 1. USER PROFILE & GLOBAL SETTINGS (users/{userId}/profile/settings)
  // =========================================================================

  DocumentReference<Map<String, dynamic>> _settingsDoc(String userId) {
    return _firestore.collection('users').doc(userId).collection('profile').doc('settings');
  }

  /// Real-time stream of User Profile & Global Settings
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserSettings(String userId) {
    return _settingsDoc(userId).snapshots();
  }

  /// Fetch user settings once
  Future<Map<String, dynamic>?> getUserSettings(String userId) async {
    try {
      final doc = await _settingsDoc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user settings from Firestore: $e');
      return null;
    }
  }

  /// Ensure settings doc exists with initial defaults
  Future<void> ensureUserSettings(
    String userId, {
    String? name,
    String? email,
    String? avatarUrl,
    bool isPrivacyMode = false,
    bool biometricEnabled = false,
    String reminderTime = '21:00',
  }) async {
    try {
      final doc = await _settingsDoc(userId)
          .get()
          .timeout(const Duration(seconds: 3));
      if (!doc.exists) {
        await _settingsDoc(userId).set({
          'name': name ?? 'User',
          'email': email ?? '',
          'avatarUrl': avatarUrl ?? '',
          'isPrivacyMode': isPrivacyMode,
          'biometricEnabled': biometricEnabled,
          'reminderTime': reminderTime,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('Error ensuring user settings in Firestore: $e');
    }
  }

  /// Update any user profile or settings fields
  Future<void> updateUserSettings(String userId, Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['updatedAt'] = FieldValue.serverTimestamp();
      await _settingsDoc(userId).set(payload, SetOptions(merge: true));

      // Also mirror avatarUrl and name to root users/{userId} for indexers
      if (data.containsKey('avatarUrl') || data.containsKey('name')) {
        final rootPayload = <String, dynamic>{};
        if (data.containsKey('avatarUrl')) rootPayload['avatarUrl'] = data['avatarUrl'];
        if (data.containsKey('name')) rootPayload['name'] = data['name'];
        await _firestore.collection('users').doc(userId).set(rootPayload, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error updating user settings in Firestore: $e');
      rethrow;
    }
  }

  /// Save avatar reference directly to users/{userId}/profile/meta & settings
  Future<void> updateAvatarUrl(String userId, String avatarUrl) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('meta')
          .set({
        'avatarUrl': avatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await updateUserSettings(userId, {
        'avatarUrl': avatarUrl,
      });
    } catch (e) {
      debugPrint('FirestoreService: updateAvatarUrl error: $e');
    }
  }

  /// Update privacy blur mode
  Future<void> updatePrivacyMode(String userId, bool isPrivacyMode) async {
    await updateUserSettings(userId, {
      'isPrivacyMode': isPrivacyMode,
    });
  }

  // =========================================================================
  // 2. TARGETS / GOALS COLLECTION (users/{userId}/targets)
  // =========================================================================

  CollectionReference<Map<String, dynamic>> _targetsCol(String userId) {
    return _firestore.collection('users').doc(userId).collection('targets');
  }

  /// Real-time stream of Targets (never omits targets without createdAt)
  Stream<List<SanchayTarget>> streamTargets(String userId, {double? liveAccumulation}) {
    return _targetsCol(userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return SanchayTarget.fromFirestore(doc, liveAccumulation: liveAccumulation);
      }).toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      return list;
    });
  }

  /// Create a new target in users/{userId}/targets
  Future<String> createTarget(String userId, SanchayTarget target) async {
    try {
      final docRef = _targetsCol(userId).doc();
      final payload = target.toFirestore();
      payload['createdAt'] = FieldValue.serverTimestamp();
      await docRef.set(payload);
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating target in Firestore: $e');
      rethrow;
    }
  }

  /// Update target properties
  Future<void> updateTarget(String userId, String targetId, Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['updatedAt'] = FieldValue.serverTimestamp();
      await _targetsCol(userId).doc(targetId).set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating target in Firestore: $e');
      rethrow;
    }
  }

  /// Toggle target pause state
  Future<void> toggleTargetPause(String userId, String targetId, bool isPaused) async {
    await updateTarget(userId, targetId, {
      'isPaused': isPaused,
    });
  }

  /// Delete target document
  Future<void> deleteTarget(String userId, String targetId) async {
    try {
      await _targetsCol(userId).doc(targetId).delete();
    } catch (e) {
      debugPrint('Error deleting target from Firestore: $e');
      rethrow;
    }
  }

  /// Set a specific target as primary vault
  Future<void> setPrimaryTarget(String userId, String targetId) async {
    try {
      final snapshot = await _targetsCol(userId).get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isPrimary': doc.id == targetId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error setting primary target: $e');
    }
  }

  /// Transfer funds between two target vaults atomically
  Future<void> transferBetweenTargets({
    required String userId,
    required String fromTargetId,
    required String toTargetId,
    required double amount,
  }) async {
    if (amount <= 0 || fromTargetId == toTargetId) return;
    try {
      final batch = _firestore.batch();
      final fromRef = _targetsCol(userId).doc(fromTargetId);
      final toRef = _targetsCol(userId).doc(toTargetId);

      batch.set(fromRef, {
        'currentAccumulation': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(toRef, {
        'currentAccumulation': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('Error transferring between targets: $e');
      rethrow;
    }
  }

  /// Ensure at least one primary target exists in users/{userId}/targets
  Future<SanchayTarget> ensurePrimaryTarget(
    String userId, {
    String title = 'Master Vault Reserve',
    double targetCap = 100000.0,
    DateTime? targetDate,
  }) async {
    try {
      final snapshot = await _targetsCol(userId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));
      if (snapshot.docs.isNotEmpty) {
        return SanchayTarget.fromFirestore(snapshot.docs.first);
      }

      // Create primary target
      final newDate = targetDate ?? DateTime.now().add(const Duration(days: 45));
      final docRef = _targetsCol(userId).doc();
      final target = SanchayTarget(
        id: docRef.id,
        title: title,
        targetCap: targetCap,
        targetDate: newDate,
        isPaused: false,
        createdAt: DateTime.now(),
      );
      await docRef
          .set(target.toFirestore())
          .timeout(const Duration(seconds: 3));
      return target;
    } catch (e) {
      debugPrint('Error ensuring primary target in Firestore: $e');
      return SanchayTarget(
        id: 'primary_vault',
        title: title,
        targetCap: targetCap,
        targetDate: targetDate ?? DateTime.now().add(const Duration(days: 45)),
      );
    }
  }

  /// Deposit funds into a Target (Goal) & log credit transaction atomically in Firestore
  Future<void> contributeToTarget({
    required String userId,
    required String targetId,
    required double amount,
    required String channel,
    String? source,
    String? merchant,
    String? category,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Increment target currentAccumulation & currentVault
      if (targetId.isNotEmpty) {
        final targetRef = _targetsCol(userId).doc(targetId);
        final docSnap = await targetRef.get();
        if (docSnap.exists) {
          batch.update(targetRef, {
            'currentAccumulation': FieldValue.increment(amount),
            'currentVault': FieldValue.increment(amount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.set(targetRef, {
            'id': targetId,
            'title': merchant ?? 'Savings Vault',
            'targetCap': 100000.0,
            'currentAccumulation': FieldValue.increment(amount),
            'currentVault': FieldValue.increment(amount),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // 2. Add credit transaction into users/{userId}/transactions
      final txDocRef = _transactionsCol(userId).doc();
      final txPayload = <String, dynamic>{
        'id': txDocRef.id,
        'amount': amount,
        'type': 'vault_deposit',
        'merchant': merchant ?? 'Primary Reserve Vault',
        'category': category ?? 'VAULT TRANSFER',
        'channel': channel,
        'source': source ?? channel,
        'timestamp': FieldValue.serverTimestamp(),
        'isAutoCaptured': false,
        'tag': 'Vault Deposit',
        'userId': userId,
        'targetId': targetId,
        'vaultId': targetId,
      };
      batch.set(txDocRef, txPayload);

      await batch.commit();
      debugPrint('FirestoreService: Contributed ₹$amount to target $targetId with tx ${txDocRef.id}');
    } catch (e) {
      debugPrint('FirestoreService: Error contributing to target: $e');
      rethrow;
    }
  }

  // =========================================================================
  // 3. LIVE TRANSACTIONS COLLECTION (users/{userId}/transactions)
  // =========================================================================

  CollectionReference<Map<String, dynamic>> _transactionsCol(String userId) {
    return _firestore.collection('users').doc(userId).collection('transactions');
  }

  /// Real-time stream of transactions ordered by timestamp descending
  Stream<List<Transaction>> streamTransactions(String userId) {
    return _transactionsCol(userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Transaction.fromFirestore(doc)).toList();
    });
  }

  /// Add manual or auto-captured transaction
  Future<void> addTransaction(String userId, Transaction tx) async {
    try {
      final docRef = _transactionsCol(userId).doc(tx.id);
      final payload = tx.toFirestore();
      payload['userId'] = userId;
      await docRef.set(payload, SetOptions(merge: true));
      debugPrint('FirestoreService: Wrote transaction ${tx.id} (${tx.merchant} ₹${tx.amount})');
    } catch (e) {
      debugPrint('FirestoreService: Error adding transaction: $e');
      rethrow;
    }
  }

  /// Delete transaction on swipe-to-delete
  Future<void> deleteTransaction(String userId, String txId) async {
    try {
      await _transactionsCol(userId).doc(txId).delete();
      debugPrint('FirestoreService: Deleted transaction $txId');
    } catch (e) {
      debugPrint('FirestoreService: Error deleting transaction: $e');
      rethrow;
    }
  }

  /// Purge all transactions in user ledger
  Future<void> purgeTransactions(String userId) async {
    try {
      final snapshot = await _transactionsCol(userId).get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('FirestoreService: Purged all ledger transactions for user $userId');
    } catch (e) {
      debugPrint('FirestoreService: Error purging ledger: $e');
      rethrow;
    }
  }
}
