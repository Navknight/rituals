import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/features/camera/preview_screen.dart';

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
  CameraController? _controller;
  bool _isReady = false;
  String? _error;

  /// Browsers have no usable in-page camera preview here, so the web build
  /// hands straight over to the system picker, which on iOS and Android opens
  /// the real camera.
  bool get _useSystemPicker => kIsWeb;

  @override
  void initState() {
    super.initState();
    if (_useSystemPicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pick(ImageSource.camera);
      });
    } else {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera on this device.');
        return;
      }
      final controller = CameraController(cameras.first, ResolutionPreset.medium);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isReady = true;
      });
    } catch (e) {
      // A denied permission or a busy camera must not leave a dead spinner.
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null) {
        // Cancelled. On web there is nothing behind this screen to show.
        if (_useSystemPicker && mounted) Navigator.of(context).pop();
        return;
      }
      if (mounted) _openPreview(picked.path, replace: true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _openPreview(String path, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => PreviewScreen(
        photoPath: path,
        groupId: widget.groupId,
        ritualId: widget.ritualId,
        completionValue: widget.completionValue,
      ),
    );
    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final photo = await controller.takePicture();
      if (mounted) _openPreview(photo.path);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _errorScaffold(context);

    if (!_isReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Camera'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 32, left: 32, right: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () => _pick(ImageSource.gallery),
                        icon: const Icon(LucideIcons.images,
                            color: Colors.white, size: 30),
                        tooltip: 'Pick from gallery',
                      ),
                      GestureDetector(
                        onTap: _shoot,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
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

  Widget _errorScaffold(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Camera'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.cameraOff,
                  size: 44, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Cannot open the camera',
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
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(LucideIcons.images, size: 18),
                label: const Text('Choose a photo instead'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isReady = false;
                  });
                  if (_useSystemPicker) {
                    _pick(ImageSource.camera);
                  } else {
                    _initCamera();
                  }
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
