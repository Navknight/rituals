import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/models/group.dart';
import 'package:share_plus/share_plus.dart';

/// Lets the user pick which space is active, and manage shared ones.
class SpacesScreen extends ConsumerWidget {
  const SpacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final activeId = ref.watch(activeSpaceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spaces')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Not signed in'));
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16, 16, 16, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              _SectionLabel('Personal'),
              const SizedBox(height: 8),
              if (profile.personalGroupId != null)
                _PersonalSpaceCard(
                  groupId: profile.personalGroupId!,
                  activeId: activeId,
                ),
              const SizedBox(height: 28),
              _SectionLabel('Shared'),
              const SizedBox(height: 8),
              if (profile.sharedGroupIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Text(
                    'Rituals are yours alone until you share them.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...profile.sharedGroupIds.map(
                  (id) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SharedSpaceCard(
                      groupId: id,
                      activeId: activeId,
                      uid: profile.uid,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _createSpace(context, ref, profile.uid),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Create a shared space'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _showJoinSheet(context, ref, profile.uid),
                icon: const Icon(LucideIcons.keyRound, size: 18),
                label: const Text('Join with a code'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createSpace(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a shared space'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Space name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;

    final groupService = ref.read(groupServiceProvider);
    final userService = ref.read(userServiceProvider);
    final group = await groupService.createGroup(name, uid);
    await userService.addGroup(uid, group.id);
    if (!context.mounted) return;
    ref.read(activeSpaceProvider.notifier).select(group.id);
    Navigator.pop(context);
  }

  Future<void> _showJoinSheet(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _JoinSpaceSheet(uid: uid),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PersonalSpaceCard extends ConsumerWidget {
  const _PersonalSpaceCard({required this.groupId, required this.activeId});

  final String groupId;
  final String? activeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final scheme = Theme.of(context).colorScheme;
    final group = groupAsync.value;
    final isActive = activeId == groupId;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(LucideIcons.lock, color: scheme.primary),
        title: Text(group?.name ?? 'My Rituals'),
        subtitle: const Text('Private'),
        trailing: isActive
            ? Icon(LucideIcons.check, color: scheme.primary)
            : null,
        onTap: () {
          ref.read(activeSpaceProvider.notifier).select(groupId);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _SharedSpaceCard extends ConsumerWidget {
  const _SharedSpaceCard({
    required this.groupId,
    required this.activeId,
    required this.uid,
  });

  final String groupId;
  final String? activeId;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final scheme = Theme.of(context).colorScheme;
    final group = groupAsync.value;
    final isActive = activeId == groupId;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(LucideIcons.users, color: scheme.primary),
        title: Text(group?.name ?? 'Space'),
        subtitle: Text('${group?.memberIds.length ?? 0} members'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) Icon(LucideIcons.check, color: scheme.primary),
            PopupMenuButton<String>(
              onSelected: (value) =>
                  _onMenuSelected(context, ref, value, group),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'invite', child: Text('Invite')),
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'leave', child: Text('Leave')),
              ],
            ),
          ],
        ),
        onTap: () {
          ref.read(activeSpaceProvider.notifier).select(groupId);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    WidgetRef ref,
    String action,
    Group? group,
  ) async {
    if (group == null) return;
    switch (action) {
      case 'invite':
        await showInviteSheet(context, group);
      case 'rename':
        await _rename(context, ref, group);
      case 'leave':
        await _leave(context, ref, group);
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Group group) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename space'),
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
    await ref.read(groupServiceProvider).rename(group.id, name);
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave space'),
        content: Text(
          'You will lose access to "${group.name}" and its rituals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final groupService = ref.read(groupServiceProvider);
    final userService = ref.read(userServiceProvider);
    final wasLastMember = group.memberIds.length <= 1;

    await groupService.leaveGroup(group.id, uid);
    await userService.removeGroup(uid, group.id);
    if (wasLastMember) {
      await groupService.deleteGroup(group.id, group.inviteCode);
    }
  }
}

class _JoinSpaceSheet extends ConsumerStatefulWidget {
  const _JoinSpaceSheet({required this.uid});

  final String uid;

  @override
  ConsumerState<_JoinSpaceSheet> createState() => _JoinSpaceSheetState();
}

class _JoinSpaceSheetState extends ConsumerState<_JoinSpaceSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const _QrScanScreen()),
    );
    if (code == null) return;
    if (!mounted) return;
    setState(() => _controller.text = inviteCodeFrom(code));
    await _submit();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _busy) return;

    setState(() => _busy = true);
    final groupService = ref.read(groupServiceProvider);
    final userService = ref.read(userServiceProvider);
    final result = await groupService.joinGroup(code, widget.uid);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.ok) {
      await userService.addGroup(widget.uid, result.group!.id);
      if (!mounted) return;
      ref.read(activeSpaceProvider.notifier).select(result.group!.id);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not join that space')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Join with a code',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                UpperCaseTextFormatter(),
              ],
              decoration: const InputDecoration(counterText: ''),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scan,
              icon: const Icon(LucideIcons.scanLine, size: 18),
              label: const Text('Scan QR code'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR code')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}

/// Shows the invite code, its QR image, and share actions for a space.
Future<void> showInviteSheet(BuildContext context, Group group) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _InviteSheet(group: group),
  );
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.group});

  final Group group;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: group.inviteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code copied')));
  }

  Future<void> _share() {
    return SharePlus.instance.share(
      ShareParams(
        text:
            'Join my space "${group.name}" on Rituals.\n\n'
            'Code: ${group.inviteCode}\n'
            '${inviteLinkFor(group.inviteCode)}',
        subject: 'Join ${group.name} on Rituals',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 24, 20, 32 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(group.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          QrImageView(
            data: inviteLinkFor(group.inviteCode),
            size: 200,
            backgroundColor: Colors.transparent,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: scheme.onSurface,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            group.inviteCode,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 10,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(LucideIcons.copy, size: 18),
                  label: const Text('Copy code'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _share,
                  icon: const Icon(LucideIcons.share2, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
