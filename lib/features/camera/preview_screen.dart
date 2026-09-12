import 'dart:io';

import 'package:camera/camera.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/features/camera/camera_provider.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  final String photoPath;
  final String groupId;
  final String ritualId;
  final double completionValue;

  const PreviewScreen({
    super.key,
    required this.photoPath,
    required this.groupId,
    required this.ritualId,
    this.completionValue = 1,
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
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake'),
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;

      final rawBytes = kIsWeb
          ? await XFile(widget.photoPath).readAsBytes()
          : await File(widget.photoPath).readAsBytes();

      final photoService = ref.read(photoServiceProvider);
      final result = await photoService.compressAndSave(rawBytes);
      final url = await photoService.uploadToRelay(
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

      if (mounted && context.mounted) {
        var count = 0;
        Navigator.of(context).popUntil((_) => count++ >= 2);
      }
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
