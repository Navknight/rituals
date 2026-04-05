import 'package:cloud_firestore/cloud_firestore.dart';

class RitualEntry {
  final String id;
  final String userId;
  final String photoUrl;
  final String? localPath;
  final String? caption;
  final DateTime createdAt;

  RitualEntry({
    required this.id,
    required this.userId,
    required this.photoUrl,
    this.localPath,
    this.caption,
    required this.createdAt,
  });

  factory RitualEntry.fromMap(Map<String, dynamic> map) {
    return RitualEntry(
      id: map['id'] as String,
      userId: map['userId'] as String,
      photoUrl: map['photoUrl'] as String,
      localPath: map['localPath'] as String?,
      caption: map['caption'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'photoUrl': photoUrl,
      'localPath': localPath,
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
