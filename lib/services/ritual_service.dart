import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rituals/models/ritual.dart';

class RitualService {
  final firestore = FirebaseFirestore.instance;

  Future<void> createRitual(String groupId, Ritual ritual) async {
    final docRef = await firestore
        .collection('groups')
        .doc(groupId)
        .collection('rituals')
        .add(ritual.toMap());

    await docRef.update({'id': docRef.id});
  }

  Stream<List<Ritual>> getRituals(String groupId) {
    return firestore
        .collection('groups')
        .doc(groupId)
        .collection('rituals')
        .snapshots()
        .map(
          (querySnapshot) => querySnapshot.docs
              .map((doc) => Ritual.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> deleteRitual(String groupId, String ritualId) async {
    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('rituals')
        .doc(ritualId)
        .delete();
  }
}
