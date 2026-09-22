import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rituals/features/camera/preview_screen.dart';
import 'package:rituals/models/ritual.dart';

/// What the screen can show: the camera coming up, the live preview, or the
/// fallback when the camera cannot be opened at all.
enum _Stage { loading, ready, unavailable }

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.groupId,
    required this.ritual,
    this.completionValue = 1,
  });

  final String groupId;
  final Ritual ritual;

  /// Progress the photo logs when it is saved.
  final double completionValue;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  _Stage _stage = _Stage.loading;
  String _problem = '';

  bool get _galleryAllowed => widget.ritual.galleryAllowed;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  /// A missing camera, a denied permission or a locked-down browser all end up
  /// here. Without this the screen used to spin forever.
  Future<void> _initCamera() async {
    setState(() {
      _stage = _Stage.loading;
      _problem = '';
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera on this device.');
      }
      final controller = CameraController(cameras.first, ResolutionPreset.medium);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _stage = _Stage.ready;
      });
    } catch (e) {
      debugPrint('[CameraScreen] camera unavailable: $e');
      if (!mounted) return;
      setState(() {
        _stage = _Stage.unavailable;
        _problem = e is CameraException
            ? (e.description ?? e.code)
            : 'The camera could not be opened.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Hands [photoPath] to the preview. When the preview reports a saved photo
  /// this screen closes too, so the caller lands back where it started
  /// whichever source the photo came from.
  Future<void> _openPreview(String photoPath, {bool fromGallery = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          photoPath: photoPath,
          groupId: widget.groupId,
          ritualId: widget.ritual.id,
          completionValue: widget.completionValue,
          fromGallery: fromGallery,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked != null && mounted) {
        await _openPreview(picked.path, fromGallery: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the gallery: $e')),
      );
    }
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;
    try {
      final photo = await controller.takePicture();
      if (mounted) await _openPreview(photo.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not take the photo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _stage == _Stage.ready;
    return Scaffold(
      backgroundColor: dark ? Colors.black : null,
      appBar: AppBar(
        title: Text(widget.ritual.title),
        centerTitle: true,
        backgroundColor: dark ? Colors.black : null,
        foregroundColor: dark ? Colors.white : null,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: switch (_stage) {
              _Stage.loading => const CircularProgressIndicator(),
              _Stage.ready => _cameraView(),
              _Stage.unavailable => _fallbackView(),
            },
          ),
        ),
      ),
    );
  }

  Widget _cameraView() {
    return Column(
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
          padding: const EdgeInsets.only(bottom: 32, left: 32, right: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The gallery is only an option for rituals that opted in, so a
              // proof-first ritual cannot quietly be satisfied with an old photo.
              SizedBox(
                width: 48,
                child: _galleryAllowed
                    ? IconButton(
                        onPressed: _pickFromGallery,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                        tooltip: 'Pick from gallery',
                      )
                    : null,
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
              // Balances the row against the gallery slot.
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallbackView() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_outlined,
              size: 44, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text('Camera unavailable', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _galleryAllowed
                ? '$_problem You can still pick a photo from the gallery.'
                : '$_problem Check the camera permission and try again.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (_galleryAllowed)
            FilledButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Choose from gallery'),
            ),
          if (_galleryAllowed) const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _initCamera,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try the camera again'),
          ),
        ],
      ),
    );
  }
}
