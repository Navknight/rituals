import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:rituals/models/ritual_entry.dart';

class PhotoService {
  Future<({Uint8List bytes, String? localPath})> compressAndSave(
    Uint8List rawBytes,
  ) async {
    final original = img.decodeImage(rawBytes);
    final resized = img.copyResize(original!, width: 800);
    final compressedBytes = Uint8List.fromList(
      img.encodeJpg(resized, quality: 80),
    );

    String? localPath;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/rituals_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(compressedBytes);
      localPath = file.path;
    }

    return (bytes: compressedBytes, localPath: localPath);
  }

  Future<String> uploadToRelay(
    Uint8List photoBytes,
    String groupId,
    String ritualId,
  ) async {
    final path =
        'relay/$groupId/$ritualId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(photoBytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<void> createEntry(
    String groupId,
    String ritualId,
    RitualEntry entry,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final docRef = await firestore
        .collection('groups')
        .doc(groupId)
        .collection('rituals')
        .doc(ritualId)
        .collection('entries')
        .add(entry.toMap());

    await docRef.update({'id': docRef.id});
  }
}
