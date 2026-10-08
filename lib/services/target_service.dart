import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class TargetVaultService {
  static FirebaseFirestore get _firestore => AuthService.firestoreInstance;

  static String? get _uid {
    try {
      final fbUid = FirebaseAuth.instance.currentUser?.uid;
      if (fbUid != null && fbUid.isNotEmpty) return fbUid;
    } catch (_) {}
    try {
      final authUid = AuthService().currentUserId;
      if (authUid.isNotEmpty) return authUid;
    } catch (_) {}
    return null;
  }

  // 1. Create New Goal
  static Future<bool> createVault({
    required String title,
    required double targetCap,
    required DateTime deadline,
    required String category,
    required int colorValue,
    String? bannerUrl,
  }) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      debugPrint('TargetVaultService.createVault aborted: uid is null');
      return false;
    }

    try {
      final docRef = _firestore.collection('users').doc(uid).collection('targets').doc();
      await docRef.set({
        'id': docRef.id,
        'title': title.trim(),
        'targetCap': targetCap,
        'currentAccumulation': 0.0,
        'category': category,
        'colorValue': colorValue,
        'deadline': Timestamp.fromDate(deadline),
        'targetDate': Timestamp.fromDate(deadline),
        'bannerUrl': bannerUrl ?? '',
        'imageUrl': bannerUrl ?? '',
        'isActive': true,
        'isPaused': false,
        'isPrimary': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      try {
        if (AuthService.firestoreInstance != _firestore) {
          await AuthService.firestoreInstance.collection('users').doc(uid).collection('targets').doc(docRef.id).set({
            'id': docRef.id,
            'title': title.trim(),
            'targetCap': targetCap,
            'currentAccumulation': 0.0,
            'category': category,
            'colorValue': colorValue,
            'deadline': Timestamp.fromDate(deadline),
            'targetDate': Timestamp.fromDate(deadline),
            'bannerUrl': bannerUrl ?? '',
            'imageUrl': bannerUrl ?? '',
            'isActive': true,
            'isPaused': false,
            'isPrimary': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Error creating vault: $e');
      return false;
    }
  }

  // 2. Edit / Update Existing Goal
  static Future<bool> updateVault({
    required String vaultId,
    required String title,
    required double targetCap,
    required DateTime deadline,
    required String category,
    required int colorValue,
    required bool isActive,
    required bool isPrimary,
    String? bannerUrl,
  }) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || vaultId.isEmpty) {
      debugPrint('TargetVaultService.updateVault aborted: uid or vaultId is empty');
      return false;
    }

    try {
      final data = <String, dynamic>{
        'title': title.trim(),
        'targetCap': targetCap,
        'category': category,
        'colorValue': colorValue,
        'deadline': Timestamp.fromDate(deadline),
        'targetDate': Timestamp.fromDate(deadline),
        'isActive': isActive,
        'isPaused': !isActive,
        'isPrimary': isPrimary,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (bannerUrl != null) {
        data['bannerUrl'] = bannerUrl;
        data['imageUrl'] = bannerUrl;
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('targets')
          .doc(vaultId)
          .update(data);
      try {
        if (AuthService.firestoreInstance != _firestore) {
          await AuthService.firestoreInstance
              .collection('users')
              .doc(uid)
              .collection('targets')
              .doc(vaultId)
              .update(data);
        }
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Error updating vault: $e');
      return false;
    }
  }

  // 3. Delete Goal
  static Future<bool> deleteVault(String vaultId) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || vaultId.isEmpty) {
      debugPrint('TargetVaultService.deleteVault aborted: uid or vaultId is empty');
      return false;
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('targets')
          .doc(vaultId)
          .delete();
      try {
        if (AuthService.firestoreInstance != _firestore) {
          await AuthService.firestoreInstance
              .collection('users')
              .doc(uid)
              .collection('targets')
              .doc(vaultId)
              .delete();
        }
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Error deleting vault: $e');
      return false;
    }
  }

  // 4. Synchronize Vault Balance with Transactions
  static Future<void> depositToVault({
    required String vaultId,
    required double amount,
    required String vaultTitle,
    String? userId,
  }) async {
    final uid = userId ?? _uid;
    if (uid == null || uid.isEmpty || vaultId.isEmpty || amount <= 0) {
      debugPrint('TargetVaultService.depositToVault aborted: invalid parameters');
      return;
    }

    final batch = _firestore.batch();

    // 1. Physically update the Target document accumulation
    final vaultRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('targets')
        .doc(vaultId);

    final vaultDoc = await vaultRef.get();
    if (vaultDoc.exists) {
      batch.update(vaultRef, {
        'currentAccumulation': FieldValue.increment(amount),
        'currentVault': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(vaultRef, {
        'id': vaultId,
        'title': vaultTitle.trim(),
        'targetCap': 100000.0,
        'currentAccumulation': FieldValue.increment(amount),
        'currentVault': FieldValue.increment(amount),
        'isActive': true,
        'isPaused': false,
        'isPrimary': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 2. Add to Vault Activity Log
    final txRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc();

    batch.set(txRef, {
      'id': txRef.id,
      'title': 'Vault Transfer: $vaultTitle',
      'amount': amount,
      'type': 'vault_deposit',
      'vaultId': vaultId,
      'targetId': vaultId,
      'merchant': vaultTitle,
      'category': 'VAULT TRANSFER',
      'channel': 'VAULT_MANUAL',
      'source': 'Manual Deposit',
      'isAutoCaptured': false,
      'tag': 'Vault Deposit',
      'userId': uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Instance method convenience alias
  Future<void> deposit({
    required String vaultId,
    required double amount,
    required String vaultTitle,
    String? userId,
  }) => depositToVault(
    vaultId: vaultId,
    amount: amount,
    vaultTitle: vaultTitle,
    userId: userId,
  );
}

/// Backward-compatible service alias
class TargetService {
  Future<void> depositToVault({
    required String vaultId,
    required double amount,
    required String vaultTitle,
    String? userId,
  }) => TargetVaultService.depositToVault(
    vaultId: vaultId,
    amount: amount,
    vaultTitle: vaultTitle,
    userId: userId,
  );
}

