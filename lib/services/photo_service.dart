import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';


/// Thrown when the bytes handed over are not an image this app can read.
class UnreadablePhotoException implements Exception {
  const UnreadablePhotoException();

  @override
  String toString() =>
      'That file is not an image this app can read. Try a JPEG or PNG.';
}

/// Shrinks a photo to something worth uploading. Top-level and pure so it can
/// run off the UI thread: decoding a full-size gallery photo on the main
/// isolate drops frames for a noticeable beat.
Uint8List _compress(Uint8List rawBytes) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) throw const UnreadablePhotoException();

  // Gallery photos carry their rotation in EXIF rather than in the pixels, so
  // without this a portrait shot is re-encoded on its side.
  final upright = img.bakeOrientation(decoded);

  // Never scale up: a small photo only gets blurrier and heavier for it.
  final resized = upright.width > 800
      ? img.copyResize(upright, width: 800)
      : upright;

  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}

class PhotoService {
  Future<({Uint8List bytes, String? localPath})> compressAndSave(
    Uint8List rawBytes,
  ) async {
    final compressedBytes = await compute(_compress, rawBytes);

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
}
