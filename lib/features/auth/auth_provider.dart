import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/services/auth_service.dart';

final StreamProvider<User?> authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final Provider<AuthService> authServiceProvider = Provider<AuthService>((ref) => AuthService());
