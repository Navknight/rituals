import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RestoreService {
  final _firestore = FirebaseFirestore.instance;

  /// Called when an image fails to load — writes an idempotent restore request
  /// so any peer that has the photo can re-upload it.
  Future<void> requestRestore({
    required String groupId,
    required String ritualId,
    required String entryId,
    required String originalUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Use a deterministic doc ID so duplicate requests from multiple clients collapse.
    final docId = '${groupId}_${ritualId}_$entryId';
    try {
      await _firestore.collection('restoreRequests').doc(docId).set({
        'groupId': groupId,
        'ritualId': ritualId,
        'entryId': entryId,
        'originalUrl': originalUrl,
        'requestedAt': FieldValue.serverTimestamp(),
        'requestedBy': uid,
      }, SetOptions(merge: true));
      debugPrint('[RestoreService] Requested restore for $entryId');
    } catch (e) {
      debugPrint('[RestoreService] requestRestore failed: $e');
    }
  }

  /// Called on app open. For each pending restore request in our groups:
  /// - Android: checks for local file, re-uploads if found
  /// - Web: fetches original URL (service worker serves from cache if available)
  Future<void> processPendingRequests(List<String> groupIds) async {
    if (groupIds.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('[RestoreService] processPendingRequests uid=$uid groupIds=$groupIds');

    try {
      final snapshot = await _firestore
          .collection('restoreRequests')
          .where('groupId', whereIn: groupIds)
          .get();

      debugPrint('[RestoreService] found ${snapshot.docs.length} pending requests');
      for (final doc in snapshot.docs) {
        final data = doc.data();
        await _tryFulfill(
          requestDocId: doc.id,
          groupId: data['groupId'] as String,
          ritualId: data['ritualId'] as String,
          entryId: data['entryId'] as String,
          originalUrl: data['originalUrl'] as String,
        );
      }
    } catch (e) {
      debugPrint('[RestoreService] processPendingRequests failed: $e');
    }
  }

  Future<void> _tryFulfill({
    required String requestDocId,
    required String groupId,
    required String ritualId,
    required String entryId,
    required String originalUrl,
  }) async {
    try {
      final entryDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('rituals')
          .doc(ritualId)
          .collection('entries')
          .doc(entryId)
          .get();

      if (!entryDoc.exists) {
        // Entry was deleted — clean up the dangling request
        await _firestore.collection('restoreRequests').doc(requestDocId).delete();
        return;
      }

      Uint8List? bytes;

      if (!kIsWeb) {
        // Android: check for the local file saved at capture time
        final localPath = entryDoc.data()?['localPath'] as String?;
        if (localPath != null && localPath.isNotEmpty) {
          final file = File(localPath);
          if (file.existsSync()) {
            bytes = await file.readAsBytes();
          }
        }
      } else {
        // Web: fetch the original URL. The service worker intercepts this and
        // serves from its cache if the photo was ever viewed on this device.
        try {
          final response = await http.get(Uri.parse(originalUrl));
          if (response.statusCode == 200) {
            bytes = response.bodyBytes;
          }
        } catch (_) {
          // Not cached / network error — this device can't help
        }
      }

      if (bytes == null) return; // This device can't fulfill the request

      // Re-upload to the relay Storage bucket
      final path =
          'relay/$groupId/$ritualId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final newUrl = await ref.getDownloadURL();

      // Update the entry so all real-time listeners pick up the new URL
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('rituals')
          .doc(ritualId)
          .collection('entries')
          .doc(entryId)
          .update({'photoUrl': newUrl});

      // Clean up the request
      await _firestore
          .collection('restoreRequests')
          .doc(requestDocId)
          .delete();

      debugPrint('[RestoreService] Restored $entryId → $newUrl');
    } catch (e) {
      debugPrint('[RestoreService] _tryFulfill $requestDocId failed: $e');
    }
  }
}
