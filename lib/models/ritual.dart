import 'package:cloud_firestore/cloud_firestore.dart';

class Ritual {
  final String id;
  final String title;
  final String emoji;
  final List<int> scheduleDays;
  final String? reminderTime;
  final String createdBy;
  final DateTime createdAt;

  Ritual({
    required this.id,
    required this.title,
    required this.emoji,
    required this.scheduleDays,
    this.reminderTime,
    required this.createdBy,
    required this.createdAt,
  });

  bool isScheduledForDay(int day) {
    return scheduleDays.contains(day);
  }

  factory Ritual.fromMap(Map<String, dynamic> map) {
    return Ritual(
      id: map['id'] as String,
      title: map['title'] as String,
      emoji: map['emoji'] as String,
      scheduleDays: List<int>.from(map['scheduleDays'] as List<dynamic>),
      reminderTime: map['reminderTime'] as String?,
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'emoji': emoji,
      'scheduleDays': scheduleDays,
      'reminderTime': reminderTime,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
