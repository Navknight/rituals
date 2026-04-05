import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/services/user_service.dart';

final userServiceProvider = Provider<UserService>((ref) => UserService());
