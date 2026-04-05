import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/services/ritual_service.dart';

final ritualServiceProvider = Provider<RitualService>((ref) => RitualService());

final ritualsProvider = StreamProvider.family((ref, String groupId) {
  final ritualService = ref.watch(ritualServiceProvider);
  return ritualService.getRituals(groupId);
});
