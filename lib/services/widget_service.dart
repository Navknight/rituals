import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Feeds the Android home screen widget.
///
/// There is no iOS widget extension in this project yet, so every call is a
/// no-op there as well as on web.
class WidgetService {
  static const _androidWidgetName = 'RitualWidgetProvider';
  static const _appGroupId = 'group.io.github.navknight.rituals';

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      debugPrint('[WidgetService] app group setup failed: $e');
    }
  }

  Future<void> updateWidget({
    required String photoUrl,
    required String posterName,
    String? caption,
    String? ritualTitle,
    int? streak,

    /// On-device copy of the photo. The widget can only draw from a file, so
    /// without this it has nothing to show.
    String? localPath,
  }) async {
    if (!_supported) return;
    try {
      await HomeWidget.saveWidgetData<String>('photoUrl', photoUrl);
      await HomeWidget.saveWidgetData<String>('localPath', localPath ?? '');
      await HomeWidget.saveWidgetData<String>('posterName', posterName);
      await HomeWidget.saveWidgetData<String>('caption', caption ?? '');
      await HomeWidget.saveWidgetData<String>('ritualTitle', ritualTitle ?? '');
      await HomeWidget.saveWidgetData<String>(
        'streak',
        streak == null ? '' : '$streak',
      );
      await HomeWidget.saveWidgetData<String>(
        'timestamp',
        DateTime.now().toIso8601String(),
      );
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      debugPrint('[WidgetService] update failed: $e');
    }
  }
}
