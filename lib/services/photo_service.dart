import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PhotoService {
  /// Keeps a copy on device. The picker has already resized and compressed.
  Future<String?> saveLocal(Uint8List bytes) async {
    if (kIsWeb) return null;
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/rituals_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes);
    return file.path;
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
}
