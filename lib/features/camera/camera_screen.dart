import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/features/camera/preview_screen.dart';

/// Hands capture to the system camera app rather than driving the sensor in
/// process.
///
/// A custom Camera2 preview gets the raw sensor output and none of the OEM
/// pipeline, so photos come out visibly worse than the phone's own camera.
/// The system app also covers permissions, flash, lenses and night mode for
/// free, and works the same way in a browser.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.groupId,
    required this.ritualId,
    this.completionValue = 1,
  });

  final String groupId;
  final String ritualId;

  /// Progress the photo logs when it is saved.
  final double completionValue;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _picker = ImagePicker();
  bool _opening = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pick(ImageSource.camera);
    });
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        // Let the OEM pipeline do the work; only cap the longest edge so a
        // 50MP original does not have to be read into memory whole.
        maxWidth: 2048,
        imageQuality: 92,
      );
      if (!mounted) return;

      if (picked == null) {
        Navigator.of(context).pop();
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PreviewScreen(
            photoPath: picked.path,
            groupId: widget.groupId,
            ritualId: widget.ritualId,
            completionValue: widget.completionValue,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _opening = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Photo'), centerTitle: true),
      body: Center(
        child: _opening
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.cameraOff,
                        size: 44, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text('Could not open the camera',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      _error ?? '',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(LucideIcons.camera, size: 18),
                      label: const Text('Try again'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(LucideIcons.images, size: 18),
                      label: const Text('Choose a photo instead'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
