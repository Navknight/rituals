import 'dart:io';

import 'package:camera/camera.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/services/widget_service.dart';
import 'package:rituals/features/camera/camera_provider.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  final String photoPath;
  final String groupId;
  final String ritualId;
  final double completionValue;

  /// Whether the photo came from the gallery, which only changes the wording
  /// of the "go back and choose again" button.
  final bool fromGallery;

  const PreviewScreen({
    super.key,
    required this.photoPath,
    required this.groupId,
    required this.ritualId,
    this.completionValue = 1,
    this.fromGallery = false,
  });

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  final captionController = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: kIsWeb
                          ? Image.network(
                              widget.photoPath,
                              fit: BoxFit.contain,
                              width: double.infinity,
                            )
                          : Image.file(
                              File(widget.photoPath),
                              fit: BoxFit.contain,
                              width: double.infinity,
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: captionController,
                    decoration: const InputDecoration(
                      labelText: 'Add a caption...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          icon: Icon(widget.fromGallery
                              ? Icons.photo_library_outlined
                              : Icons.refresh),
                          label: Text(
                            widget.fromGallery ? 'Pick another' : 'Retake',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(_saving ? 'Saving...' : 'Share'),
                        ),
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

  /// Push a photo the user just took straight to the home screen widget,
  /// rather than waiting for a notification that never comes in a space of one.
  Future<void> _refreshWidget(String uid, String caption) async {
    try {
      final rituals = await ref.read(ritualsProvider(widget.groupId).future);
      final ritual = rituals.where((r) => r.id == widget.ritualId).firstOrNull;
      if (ritual == null) return;

      final entries = await ref
          .read(ritualServiceProvider)
          .fetchRitualEntries(widget.groupId, widget.ritualId);
      final streak = ref
          .read(streakServiceProvider)
          .analyse(ritual: ritual, entries: entries)
          .currentStreak;

      final profile = await ref.read(userServiceProvider).getProfile(uid);
      await WidgetService().updateWidget(
        photoUrl: _uploadedUrl ?? '',
        localPath: _localPath,
        posterName: profile?.displayName ?? 'You',
        caption: caption.isEmpty ? null : caption,
        ritualTitle: ritual.title,
        streak: streak,
      );
    } catch (e) {
      debugPrint('[PreviewScreen] widget refresh failed: $e');
    }
  }

  String? _uploadedUrl;
  String? _localPath;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = ref.read(currentUidProvider);
      // Without this the button would sit on "Saving..." forever.
      if (uid == null) throw StateError('You are signed out.');

      final rawBytes = kIsWeb
          ? await XFile(widget.photoPath).readAsBytes()
          : await File(widget.photoPath).readAsBytes();

      final photoService = ref.read(photoServiceProvider);
      final result = await photoService.compressAndSave(rawBytes);
      _localPath = result.localPath;
      final url = _uploadedUrl = await photoService.uploadToRelay(
        result.bytes,
        widget.groupId,
        widget.ritualId,
      );

      final caption = captionController.text.trim();
      await ref.read(ritualServiceProvider).logEntry(
            groupId: widget.groupId,
            ritualId: widget.ritualId,
            userId: uid,
            day: DateTime.now(),
            value: widget.completionValue,
            photoUrl: url,
            localPath: result.localPath,
            caption: caption.isEmpty ? null : caption,
          );

      await _refreshWidget(uid, caption);

      // Report the save upward; the camera screen closes itself in turn, so
      // the stack unwinds the same way whether the photo was shot or picked.
      if (mounted && context.mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
