import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/app/theme.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/core/settings_provider.dart';
import 'package:rituals/features/auth/sign_in_screen.dart';
import 'package:rituals/features/spaces/spaces_screen.dart';
import 'package:rituals/shared/user_avatar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('Account'),
          profileAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$e'),
            ),
            data: (profile) {
              final name = profile?.displayName ?? 'Someone';
              return Column(
                children: [
                  ListTile(
                    leading: UserAvatar(name: name, photoUrl: profile?.photoUrl),
                    title: Text(name),
                    subtitle: Text(
                      isAnonymous ? 'Guest account' : (user?.email ?? ''),
                    ),
                    trailing: const Icon(LucideIcons.pencil, size: 18),
                    onTap: () => _renameProfile(context, ref, name),
                  ),
                  if (isAnonymous) _GuestUpgradeCard(),
                  ListTile(
                    leading: Icon(LucideIcons.logOut, color: scheme.error),
                    title: Text('Sign out', style: TextStyle(color: scheme.error)),
                    onTap: () => _confirmSignOut(context, ref, isAnonymous),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 32),
          _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) => ref
                  .read(settingsProvider.notifier)
                  .setThemeMode(selection.first),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: AccentColor.values.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final accent = AccentColor.values[index];
                final selected = settings.accent == accent;
                final accentColor =
                    buildTheme(accent, Brightness.light).colorScheme.primary;
                return Tooltip(
                  message: accent.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () =>
                        ref.read(settingsProvider.notifier).setAccent(accent),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: scheme.onSurface, width: 3)
                            : null,
                      ),
                      child: selected
                          ? const Icon(LucideIcons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 32),
          _SectionHeader('Behaviour'),
          SwitchListTile(
            title: const Text('Celebrate completions'),
            subtitle: const Text('Confetti when you finish a ritual'),
            value: settings.celebrate,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setCelebrate(value),
          ),
          const Divider(height: 32),
          _SectionHeader('Spaces'),
          ListTile(
            leading: Icon(LucideIcons.layers, color: scheme.primary),
            title: const Text('Manage spaces'),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SpacesScreen()),
            ),
          ),
          const Divider(height: 32),
          _SectionHeader('About'),
          const ListTile(
            title: Text('Rituals'),
            subtitle: Text('Track the habits you care about, alone or together.'),
          ),
          const ListTile(title: Text('Version'), subtitle: Text('1.0.0')),
        ],
      ),
    );
  }

  Future<void> _renameProfile(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(userServiceProvider).setDisplayName(uid, name);
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    bool isAnonymous,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: Text(
          isAnonymous
              ? 'This is a guest account. Once you sign out, its rituals and '
                  'streaks cannot be recovered.'
              : 'You can sign back in at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await ref.read(authServiceProvider).signOut();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _GuestUpgradeCard extends ConsumerWidget {
  const _GuestUpgradeCard();

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authServiceProvider).linkGuestToGoogle();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Card(
        color: scheme.primaryContainer,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save your progress',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'A guest account only lives on this device, in this login '
                'session. Connect a Google account so your rituals and '
                'streaks are safe.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _connect(context, ref),
                icon: const Icon(LucideIcons.logIn, size: 18),
                label: const Text('Connect Google account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
