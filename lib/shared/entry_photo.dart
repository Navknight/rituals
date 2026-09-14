import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/models/ritual_entry.dart';
import 'package:rituals/services/local_photo_store.dart';
import 'package:rituals/services/restore_service.dart';

/// Shows a ritual photo, preferring the copy held on this device.
///
/// The relay in Firebase Storage is pruned, so a network-only image is the
/// one that eventually 404s. Reading locally first also means the photo
/// appears instantly and works offline.
class EntryPhoto extends StatefulWidget {
  const EntryPhoto({
    super.key,
    required this.entry,
    required this.groupId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
  });

  final RitualEntry entry;
  final String groupId;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Decode width in pixels, so small thumbnails don't hold full photos.
  final int? cacheWidth;

  @override
  State<EntryPhoto> createState() => _EntryPhotoState();
}

class _EntryPhotoState extends State<EntryPhoto> {
  late Future<Uint8List?> _local;

  @override
  void initState() {
    super.initState();
    _local = LocalPhotoStore.instance.bytesFor(
      entryId: widget.entry.id,
      localPath: widget.entry.localPath,
    );
  }

  @override
  void didUpdateWidget(EntryPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _local = LocalPhotoStore.instance.bytesFor(
        entryId: widget.entry.id,
        localPath: widget.entry.localPath,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _local,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _placeholder(context, spinning: true);
        }
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            cacheWidth: widget.cacheWidth,
          );
        }
        return _network(context);
      },
    );
  }

  Widget _network(BuildContext context) {
    final url = widget.entry.photoUrl;
    if (url == null || url.isEmpty) return _placeholder(context);

    return Image.network(
      url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      cacheWidth: widget.cacheWidth,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(context, spinning: true),
      errorBuilder: (context, _, _) {
        _requestRestore(url);
        return _placeholder(context, gone: true);
      },
    );
  }

  /// Entry ids already asked for this session, so rebuilds don't rewrite it.
  static final _requested = <String>{};

  void _requestRestore(String url) {
    if (!_requested.add(widget.entry.id)) return;
    RestoreService().requestRestore(
      groupId: widget.groupId,
      ritualId: widget.entry.ritualId,
      entryId: widget.entry.id,
      originalUrl: url,
    );
  }

  Widget _placeholder(
    BuildContext context, {
    bool spinning = false,
    bool gone = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: widget.width,
      height: widget.height,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: spinning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              gone ? LucideIcons.imageOff : LucideIcons.image,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
    );
  }
}
