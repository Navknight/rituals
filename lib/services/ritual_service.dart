import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/models/ritual_entry.dart';

/// Reads and writes rituals and their daily logs.
///
/// Logs live in one flat `groups/{groupId}/entries` collection rather than
/// nested under each ritual. The Today screen can then load a whole day with a
/// single equality-only query, which Firestore serves without a composite
/// index, and every list is small enough to sort on the client.
class RitualService {
  final firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _group(String groupId) =>
      firestore.collection('groups').doc(groupId);

  CollectionReference<Map<String, dynamic>> _rituals(String groupId) =>
      _group(groupId).collection('rituals');

  CollectionReference<Map<String, dynamic>> _entries(String groupId) =>
      _group(groupId).collection('entries');

  Future<Ritual> createRitual(String groupId, Ritual ritual) async {
    final docRef = await _rituals(groupId).add(ritual.toMap());
    await docRef.update({'id': docRef.id});
    return ritual.copyWith(id: docRef.id);
  }

  Future<void> updateRitual(String groupId, Ritual ritual) async {
    await _rituals(groupId).doc(ritual.id).update(ritual.toMap());
  }

  Future<void> setArchived(
    String groupId,
    String ritualId,
    bool archived,
  ) async {
    await _rituals(groupId).doc(ritualId).update({'archived': archived});
  }

  Future<void> deleteRitual(String groupId, String ritualId) async {
    final logs =
        await _entries(groupId).where('ritualId', isEqualTo: ritualId).get();
    final batch = firestore.batch();
    for (final doc in logs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_rituals(groupId).doc(ritualId));
    await batch.commit();
  }

  Stream<List<Ritual>> watchRituals(String groupId) {
    return _rituals(groupId).snapshots().map((snapshot) {
      final rituals =
          snapshot.docs.map((doc) => Ritual.fromMap(doc.data())).toList();
      rituals.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return rituals;
    });
  }

  /// Logs for [day], grouped by ritual id.
  Stream<Map<String, List<RitualEntry>>> watchDay({
    required String groupId,
    required DateTime day,
  }) {
    return _entries(groupId)
        .where('day', isEqualTo: RitualEntry.dayKey(day))
        .snapshots()
        .map((snapshot) {
      final byRitual = <String, List<RitualEntry>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ritualId = data['ritualId'] as String?;
        if (ritualId == null) continue;
        byRitual.putIfAbsent(ritualId, () => []).add(
              RitualEntry.fromMap(data),
            );
      }
      return byRitual;
    });
  }

  /// Every log in a space, so cross-ritual stats stay live without a query
  /// per ritual.
  Stream<List<RitualEntry>> watchAllEntries(String groupId) {
    return _entries(groupId).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => RitualEntry.fromMap(doc.data())).toList());
  }

  /// Every log for one ritual, newest first.
  Stream<List<RitualEntry>> watchRitualEntries(
    String groupId,
    String ritualId, {
    String? userId,
  }) {
    return _entries(groupId)
        .where('ritualId', isEqualTo: ritualId)
        .snapshots()
        .map((snapshot) {
      var entries =
          snapshot.docs.map((doc) => RitualEntry.fromMap(doc.data())).toList();
      if (userId != null) {
        entries = entries.where((e) => e.userId == userId).toList();
      }
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    });
  }

  Future<List<RitualEntry>> fetchRitualEntries(
    String groupId,
    String ritualId, {
    String? userId,
  }) async {
    final snapshot =
        await _entries(groupId).where('ritualId', isEqualTo: ritualId).get();
    var entries =
        snapshot.docs.map((doc) => RitualEntry.fromMap(doc.data())).toList();
    if (userId != null) {
      entries = entries.where((e) => e.userId == userId).toList();
    }
    entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries;
  }

  /// Writes the log for [day], replacing any existing one from this user.
  ///
  /// Quantity and timer rituals accumulate over the day, so the caller passes
  /// the new running total rather than an increment.
  Future<RitualEntry> logEntry({
    required String groupId,
    required String ritualId,
    required String userId,
    required DateTime day,
    double value = 1,
    bool skipped = false,
    String? photoUrl,
    String? localPath,
    String? caption,
  }) async {
    final key = RitualEntry.dayKey(day);

    // One log per user per ritual per day, so the id is derivable and a repeat
    // tap overwrites instead of racing to create a duplicate.
    final docId = '${ritualId}_${userId}_$key';
    final docRef = _entries(groupId).doc(docId);
    final existing = await docRef.get();

    final payload = <String, dynamic>{
      'id': docId,
      'groupId': groupId,
      'ritualId': ritualId,
      'userId': userId,
      'day': key,
      'value': skipped ? 0.0 : value,
      'skipped': skipped,
      'photoUrl': photoUrl,
      'localPath': localPath,
      'caption': caption,
      'createdAt': existing.exists
          ? existing.data()!['createdAt']
          : Timestamp.fromDate(DateTime.now()),
    };

    await docRef.set(payload, SetOptions(merge: true));
    return RitualEntry.fromMap(payload);
  }

  /// Removes the log for [day], undoing a completion or a skip.
  Future<void> clearEntry({
    required String groupId,
    required String ritualId,
    required String userId,
    required DateTime day,
  }) async {
    final docId = '${ritualId}_${userId}_${RitualEntry.dayKey(day)}';
    await _entries(groupId).doc(docId).delete();
  }

  /// Moves logs written by earlier versions, which nested them under each
  /// ritual, into the flat collection. Runs once per space.
  Future<void> migrateLegacyEntries(String groupId) async {
    final groupDoc = await _group(groupId).get();
    if (groupDoc.data()?['entriesMigrated'] == true) return;

    final rituals = await _rituals(groupId).get();
    final batch = firestore.batch();
    var moved = 0;

    for (final ritualDoc in rituals.docs) {
      final legacy = await ritualDoc.reference.collection('entries').get();
      for (final entryDoc in legacy.docs) {
        final data = entryDoc.data();
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final day = data['day'] as String? ?? RitualEntry.dayKey(createdAt);
        final userId = data['userId'] as String? ?? '';
        final docId = '${ritualDoc.id}_${userId}_$day';

        batch.set(_entries(groupId).doc(docId), {
          ...data,
          'id': docId,
          'groupId': groupId,
          'ritualId': ritualDoc.id,
          'day': day,
          'value': (data['value'] as num?)?.toDouble() ?? 1.0,
          'skipped': data['skipped'] as bool? ?? false,
        });
        batch.delete(entryDoc.reference);
        moved++;
      }
    }

    batch.update(_group(groupId), {'entriesMigrated': true});
    await batch.commit();
    if (moved > 0) {
      // ignore: avoid_print
      print('[RitualService] migrated $moved legacy entries in $groupId');
    }
  }
}
