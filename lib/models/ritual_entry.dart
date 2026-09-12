import 'package:cloud_firestore/cloud_firestore.dart';

/// One logged day for a ritual.
///
/// A skipped entry is a deliberate rest day: it neither extends nor breaks a
/// streak. Photos are optional proof, not a requirement.
class RitualEntry {
  final String id;
  final String userId;

  /// The ritual this log belongs to. Denormalised so a whole space can be read
  /// from one collection.
  final String ritualId;

  /// Local calendar day as `yyyy-MM-dd`. Grouping on this rather than on
  /// [createdAt] keeps a late-night entry on the day the user meant.
  final String day;

  /// Progress logged for the day: 1 for a checked ritual, the running count
  /// for a quantity ritual, minutes for a timer ritual.
  final double value;

  final bool skipped;

  final String? photoUrl;
  final String? localPath;
  final String? caption;

  final DateTime createdAt;

  RitualEntry({
    required this.id,
    required this.userId,
    this.ritualId = '',
    required this.day,
    this.value = 1,
    this.skipped = false,
    this.photoUrl,
    this.localPath,
    this.caption,
    required this.createdAt,
  });

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  DateTime get dayDate => parseDay(day);

  RitualEntry copyWith({
    double? value,
    bool? skipped,
    String? photoUrl,
    String? localPath,
    String? caption,
  }) {
    return RitualEntry(
      id: id,
      userId: userId,
      ritualId: ritualId,
      day: day,
      value: value ?? this.value,
      skipped: skipped ?? this.skipped,
      photoUrl: photoUrl ?? this.photoUrl,
      localPath: localPath ?? this.localPath,
      caption: caption ?? this.caption,
      createdAt: createdAt,
    );
  }

  /// `yyyy-MM-dd` for a local date.
  static String dayKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  static DateTime parseDay(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? 1970,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }

  factory RitualEntry.fromMap(Map<String, dynamic> map) {
    final createdAt =
        (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return RitualEntry(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      ritualId: map['ritualId'] as String? ?? '',
      // Entries written before day keys existed fall back to their timestamp.
      day: map['day'] as String? ?? dayKey(createdAt),
      value: (map['value'] as num?)?.toDouble() ?? 1,
      skipped: map['skipped'] as bool? ?? false,
      photoUrl: map['photoUrl'] as String?,
      localPath: map['localPath'] as String?,
      caption: map['caption'] as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'ritualId': ritualId,
      'day': day,
      'value': value,
      'skipped': skipped,
      'photoUrl': photoUrl,
      'localPath': localPath,
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
