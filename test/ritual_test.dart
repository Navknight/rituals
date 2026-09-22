import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rituals/models/ritual.dart';

Ritual _ritual({bool requirePhoto = true, bool allowGallery = false}) {
  return Ritual(
    id: 'r1',
    title: 'Swim',
    emoji: '🏊',
    requirePhoto: requirePhoto,
    allowGallery: allowGallery,
    createdBy: 'u1',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('galleryAllowed', () {
    test('a proof ritual keeps the camera to itself by default', () {
      expect(_ritual().galleryAllowed, isFalse);
    });

    test('a proof ritual can opt in', () {
      expect(_ritual(allowGallery: true).galleryAllowed, isTrue);
    });

    test('a ritual without proof has nothing to guard', () {
      expect(_ritual(requirePhoto: false).galleryAllowed, isTrue);
    });
  });

  group('serialisation', () {
    test('allowGallery survives a round trip', () {
      final restored = Ritual.fromMap({
        ..._ritual(allowGallery: true).toMap(),
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      expect(restored.allowGallery, isTrue);
      expect(restored.requirePhoto, isTrue);
    });

    test('rituals saved before the setting existed default to camera only', () {
      final legacy = _ritual(allowGallery: true).toMap()..remove('allowGallery');
      final restored = Ritual.fromMap({
        ...legacy,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      expect(restored.allowGallery, isFalse);
    });

    test('copyWith carries the setting', () {
      expect(_ritual().copyWith(allowGallery: true).allowGallery, isTrue);
      expect(_ritual(allowGallery: true).copyWith(title: 'Run').allowGallery,
          isTrue);
    });
  });
}
