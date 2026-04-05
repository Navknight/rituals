import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rituals/features/auth/auth_provider.dart';
import 'package:rituals/features/groups/group_provider.dart';
import 'package:rituals/features/groups/group_state_provider.dart';
import 'package:rituals/models/group.dart';

class GroupTab extends ConsumerStatefulWidget {
  const GroupTab({super.key, required this.groupId, this.onGroupChanged});
  final String groupId;
  final VoidCallback? onGroupChanged;

  @override
  ConsumerState<GroupTab> createState() => _GroupTabState();
}

class _GroupTabState extends ConsumerState<GroupTab> {
  Group? _group;
  Map<String, String> _memberNames = {};
  bool _loading = true;
  String? _error;
  final _joinCodeController = TextEditingController();
  final _createNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final group =
          await ref.read(groupServiceProvider).getGroup(widget.groupId);
      final names = <String, String>{};
      if (group != null) {
        for (final uid in group.memberIds) {
          final profile = await ref.read(userServiceProvider).getProfile(uid);
          names[uid] = profile?.displayName ?? 'Unknown';
        }
      }
      if (mounted) {
        setState(() {
          _group = group;
          _memberNames = names;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
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
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text('Failed to load group',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(_error!, textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() { _loading = true; _error = null; });
                                  _loadGroup();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      // User card
                      Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                                user?.displayName?[0].toUpperCase() ?? '?'),
                          ),
                          title: Text(user?.displayName ?? 'Unknown'),
                          subtitle: Text(user?.email ?? ''),
                        ),
                      ),

                      // Group info card
                      Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _group?.name ?? '',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.vpn_key,
                                      size: 18,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Text(
                                    _group?.inviteCode ?? '',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontFamily: 'monospace',
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.share, size: 20),
                                    onPressed: () {
                                      SharePlus.instance.share(
                                        ShareParams(
                                          text:
                                              'Join my Rituals group! Code: ${_group?.inviteCode}',
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const Divider(),
                              Text(
                                'Members (${_group?.memberIds.length ?? 0}/4)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Member list
                              ...(_group?.memberIds ?? []).map(
                                (uid) {
                                  final name = _memberNames[uid] ?? uid;
                                  final isYou = uid == user?.uid;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: theme
                                              .colorScheme.primaryContainer,
                                          child: Text(
                                            name[0].toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isYou ? '$name (You)' : name,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Create a new group
                      Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create a new group',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _createNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Group Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.group_add),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () async {
                                    if (user == null) return;
                                    final name =
                                        _createNameController.text.trim();
                                    if (name.isEmpty) return;
                                    final group = await ref
                                        .read(groupServiceProvider)
                                        .createGroup(name, user.uid);
                                    await ref
                                        .read(userServiceProvider)
                                        .addGroup(user.uid, group.id);
                                    if (context.mounted) {
                                      _createNameController.clear();
                                      context.go('/');
                                    }
                                  },
                                  child: const Text('Create Group'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Join another group
                      Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Join another group',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _joinCodeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Invite Code',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.vpn_key),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    if (user == null) return;
                                    final code =
                                        _joinCodeController.text.trim();
                                    if (code.isEmpty) return;
                                    final group = await ref
                                        .read(groupServiceProvider)
                                        .joinGroup(code, user.uid);
                                    if (group != null) {
                                      await ref
                                          .read(userServiceProvider)
                                          .addGroup(user.uid, group.id);
                                      if (context.mounted) {
                                        _joinCodeController.clear();
                                        context.go('/');
                                      }
                                    } else if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Invalid code or group is full'),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Join Group'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await ref
                                    .read(authServiceProvider)
                                    .signOut();
                                if (context.mounted) context.go('/');
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Sign Out'),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () async {
                                if (user == null) return;
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Leave Group?'),
                                    content: const Text(
                                        'You will no longer see this group\'s rituals.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Leave',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                await ref
                                    .read(groupServiceProvider)
                                    .leaveGroup(widget.groupId, user.uid);
                                await ref
                                    .read(userServiceProvider)
                                    .removeGroup(user.uid, widget.groupId);
                                if (context.mounted) context.go('/');
                              },
                              icon: const Icon(Icons.exit_to_app,
                                  color: Colors.red),
                              label: const Text('Leave Group',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
