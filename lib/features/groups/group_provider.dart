import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/services/group_service.dart';

final groupServiceProvider = Provider<GroupService>((ref) => GroupService());
