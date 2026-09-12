import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/models/ritual_entry.dart';
import 'package:rituals/services/local_photo_store.dart';

/// Shows a ritual photo, preferring the copy held on this device.
///
/// The relay in Firebase Storage is pruned, so a network-only image is the
/// one that eventually 404s. Reading locally first also means the photo
/// appears instantly and works offline.
class EntryPhoto extends StatefulWidget {
  const EntryPhoto({
    super.key,
    required this.entry,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final RitualEntry entry;
  final BoxFit fit;
  final double? width;
  final double? height;

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
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(context, spinning: true),
      errorBuilder: (context, _, _) => _placeholder(context, gone: true),
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
