import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/features/auth/auth_provider.dart';
import 'package:rituals/features/auth/sign_in_screen.dart';
import 'package:rituals/features/groups/group_screen.dart';
import 'package:rituals/features/groups/group_state_provider.dart';
import 'package:rituals/app/main_screen.dart';
import 'package:rituals/models/user_profiles.dart';

/// Notifies GoRouter whenever Firebase auth state changes so redirects re-run.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}

final _authNotifier = _AuthNotifier();

final GoRouter router = GoRouter(
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final onHome = state.matchedLocation.startsWith('/home/');
    // If unauthenticated and on a protected route, go to root (SignIn)
    if (user == null && onHome) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AuthGate()),
    GoRoute(
      path: '/home/:groupId',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return MainScreen(groupIds: [groupId]);
      },
    ),
  ],
);

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    debugPrint('[AuthGate] authState=${authState.runtimeType} value=${authState.value?.uid}');

    return authState.when(
      data: (user) {
        debugPrint('[AuthGate] data: user=${user?.uid}');
        if (user == null) {
          return const SignInScreen();
        } else {
          return GroupGate(uid: user.uid);
        }
      },
      loading: () {
        debugPrint('[AuthGate] loading...');
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      error: (e, st) {
        debugPrint('[AuthGate] error: $e\n$st');
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Auth error',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(e.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class GroupGate extends ConsumerStatefulWidget {
  const GroupGate({super.key, required this.uid});
  final String uid;

  @override
  ConsumerState<GroupGate> createState() => _GroupGateState();
}

class _GroupGateState extends ConsumerState<GroupGate> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    debugPrint('[GroupGate] initState uid=${widget.uid}');
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = ref.read(authStateProvider).value;
      debugPrint('[GroupGate] _loadProfile user=${user?.uid}');
      if (user == null) {
        debugPrint('[GroupGate] user is null — auth not ready yet');
        if (mounted) setState(() => _loading = false);
        return;
      }
      final profile = await ref
          .read(userServiceProvider)
          .getOrCreateProfile(user);
      debugPrint('[GroupGate] profile loaded, groupIds=${profile.groupIds}');
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
          _error = null;
        });
      }
    } catch (e, st) {
      debugPrint('[GroupGate] ERROR loading profile: $e\n$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to load profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _loadProfile();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_profile != null && _profile!.groupIds.isNotEmpty) {
      return MainScreen(groupIds: _profile!.groupIds);
    }

    return const GroupScreen();
  }
}
