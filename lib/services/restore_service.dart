import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rituals/services/local_photo_store.dart';

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
  /// Re-uploads any requested photo this device still holds.
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
          .collection('entries')
          .doc(entryId)
          .get();

      if (!entryDoc.exists) {
        // Entry was deleted — clean up the dangling request
        await _firestore.collection('restoreRequests').doc(requestDocId).delete();
        return;
      }

      // The owner holds the original; on web, any member who viewed the photo
      // has it in the service worker cache, which serves this fetch.
      var bytes = await LocalPhotoStore.instance.bytesFor(
        entryId: entryId,
        localPath: entryDoc.data()?['localPath'] as String?,
      );
      if (bytes == null && kIsWeb) {
        try {
          final response = await http.get(Uri.parse(originalUrl));
          if (response.statusCode == 200) bytes = response.bodyBytes;
        } catch (_) {
          // Not cached here — this device can't help.
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
