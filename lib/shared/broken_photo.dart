import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/models/ritual_entry.dart';
import 'package:rituals/services/restore_service.dart';

/// What a photo that would not load falls back to.
///
/// The icon is the lesser half of this. Photos are relayed through storage
/// that is cleared oldest-first, so a link going dead is expected rather than
/// exceptional, and the way one comes back is for a device that still holds
/// the file to notice and re-upload it. Nothing noticed before: the old
/// placeholder drew an icon and stopped there, so a dead link stayed dead.
/// Asking here is what starts that off, and it is idempotent — the request id
/// is derived from the entry, so every viewer hitting the same broken photo
/// collapses into one request.
class BrokenPhoto extends StatefulWidget {
  const BrokenPhoto({
    super.key,
    required this.groupId,
    required this.entry,
    this.size,
    this.iconSize = 24,
  });

  final String groupId;
  final RitualEntry entry;

  /// Box to fill, for the thumbnail strip. Null lets it size to its padding.
  final double? size;
  final double iconSize;

  @override
  State<BrokenPhoto> createState() => _BrokenPhotoState();
}

class _BrokenPhotoState extends State<BrokenPhoto> {
  @override
  void initState() {
    super.initState();
    _askForIt();
  }

  void _askForIt() {
    final url = widget.entry.photoUrl;
    if (url == null || url.isEmpty) return;
    // Deliberately not awaited: this is a background repair, and the
    // placeholder should draw immediately either way.
    RestoreService().requestRestore(
      groupId: widget.groupId,
      ritualId: widget.entry.ritualId,
      entryId: widget.entry.id,
      originalUrl: url,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = Icon(
      LucideIcons.imageOff,
      size: widget.iconSize,
      color: colorScheme.onSurfaceVariant,
    );

    if (widget.size == null) {
      return Padding(padding: const EdgeInsets.all(32), child: icon);
    }
    return Container(
      width: widget.size,
      height: widget.size,
      color: colorScheme.surfaceContainerHighest,
      child: icon,
    );
  }
}
