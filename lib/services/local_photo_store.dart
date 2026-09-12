import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps a copy of every photo on the device that took it.
///
/// Firebase Storage is a relay that gets pruned, so it cannot be the only copy
/// or a solo user loses their history. On mobile the copy is a file; on web
/// there is no filesystem, so bytes go into IndexedDB through Hive.
///
/// On iOS, Safari evicts site data after seven days of not using the browser,
/// but a PWA installed to the Home Screen is exempt. That is the difference
/// between photos that last and photos that do not.
class LocalPhotoStore {
  LocalPhotoStore._();

  static final LocalPhotoStore instance = LocalPhotoStore._();

  static const _boxName = 'ritual_photos';
  Box<Uint8List>? _box;
  bool _initFailed = false;

  Future<Box<Uint8List>?> _open() async {
    if (_box != null || _initFailed) return _box;
    try {
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        Hive.init(dir.path);
      }
      _box = await Hive.openBox<Uint8List>(_boxName);
    } catch (e) {
      // Private browsing and blocked site data both land here. Losing the
      // cache must never stop a photo being logged.
      debugPrint('[LocalPhotoStore] unavailable: $e');
      _initFailed = true;
    }
    return _box;
  }

  /// Stores [bytes] for [key], which is the entry's document id.
  Future<void> put(String key, Uint8List bytes) async {
    final box = await _open();
    try {
      await box?.put(key, bytes);
    } catch (e) {
      debugPrint('[LocalPhotoStore] put failed: $e');
    }
  }

  /// Returns the local copy, or null when this device never held one.
  Future<Uint8List?> get(String key) async {
    final box = await _open();
    try {
      return box?.get(key);
    } catch (e) {
      debugPrint('[LocalPhotoStore] get failed: $e');
      return null;
    }
  }

  Future<void> delete(String key) async {
    final box = await _open();
    try {
      await box?.delete(key);
    } catch (_) {
      // Nothing to do; a stale blob is harmless.
    }
  }

  /// Bytes for an entry, preferring the local copy and falling back to the
  /// file path written by older versions on mobile.
  Future<Uint8List?> bytesFor({
    required String entryId,
    String? localPath,
  }) async {
    final cached = await get(entryId);
    if (cached != null) return cached;

    if (!kIsWeb && localPath != null && localPath.isNotEmpty) {
      try {
        final file = File(localPath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          // Pull it into the box so later reads are uniform.
          await put(entryId, bytes);
          return bytes;
        }
      } catch (e) {
        debugPrint('[LocalPhotoStore] file read failed: $e');
      }
    }
    return null;
  }
}
