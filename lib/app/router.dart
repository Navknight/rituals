import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/app/main_screen.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/features/auth/sign_in_screen.dart';

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const _Splash(),
      error: (e, _) => _Failure(
        title: 'Could not reach your account',
        message: '$e',
        onRetry: () => ref.invalidate(authStateProvider),
      ),
      data: (user) {
        if (user == null) return const SignInScreen();
        return _SpaceGate(uid: user.uid);
      },
    );
  }
}

class _SpaceGate extends ConsumerStatefulWidget {
  const _SpaceGate({required this.uid});

  final String uid;

  @override
  ConsumerState<_SpaceGate> createState() => _SpaceGateState();
}

class _SpaceGateState extends ConsumerState<_SpaceGate> {
  Future<void>? _provisioning;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _provision();
  }

  void _provision() {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() {
      _error = null;
      _provisioning = ref
          .read(userServiceProvider)
          .getOrCreateProfile(user)
          .then((_) {})
          .catchError((Object e) {
        if (mounted) setState(() => _error = e);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _Failure(
        title: 'Could not set up your space',
        message: '$_error',
        onRetry: _provision,
      );
    }

    return FutureBuilder<void>(
      future: _provisioning,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Splash();
        }

        final profileAsync = ref.watch(profileProvider);
        return profileAsync.when(
          loading: () => const _Splash(),
          error: (e, _) => _Failure(
            title: 'Could not load your profile',
            message: '$e',
            onRetry: () => ref.invalidate(profileProvider),
          ),
          data: (profile) {
            if (profile == null) return const _Splash();

            final groupId =
                ref.watch(activeSpaceProvider.notifier).resolve(profile);
            if (groupId == null) return const _Splash();

            return MainScreen(key: ValueKey(groupId), groupId: groupId);
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.flame, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.triangleAlert,
                  size: 44, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
