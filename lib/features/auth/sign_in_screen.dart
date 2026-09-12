import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/services/auth_service.dart';
import 'package:rituals/shared/web_wrapper.dart' as web;

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_readableError(e))),
        );
      }
    }
  }

  String _readableError(Object error) {
    final text = error.toString();
    if (text.contains('operation-not-allowed')) {
      return 'Guest sign-in is turned off for this Firebase project. '
          'Enable Anonymous auth in the Firebase console.';
    }
    return 'Could not sign in: $text';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(
                      LucideIcons.flame,
                      size: 44,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Rituals',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Track the habits you care about. On your own, or with '
                    'people who will notice when you stop.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    // Google first: a returning user reinstalling will reach
                    // for the prominent button, and picking guest there gives
                    // them a new identity and an empty history.
                    if (kIsWeb)
                      web.renderButton()
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () => _run(
                            () => ref
                                .read(authServiceProvider)
                                .signInWithGoogle(),
                          ),
                          icon: const Icon(LucideIcons.logIn, size: 20),
                          label: const Text('Continue with Google'),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      'Keeps your rituals across devices and reinstalls, and '
                      'lets you join shared spaces.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'or',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _run(
                          () => ref.read(authServiceProvider).signInAsGuest(),
                        ),
                        icon: const Icon(LucideIcons.zap, size: 20),
                        label: const Text('Try it as a guest'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No account, but everything stays on this device. '
                      'Reinstalling or signing out loses it, unless you '
                      'connect an account first.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
