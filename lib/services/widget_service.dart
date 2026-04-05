import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const _androidWidgetName = 'RitualWidgetProvider';
  static const _appGroupId = 'group.com.example.rituals';

  Future<void> initialize() async {
    if (!kIsWeb) {
      await HomeWidget.setAppGroupId(_appGroupId);
    }
  }

  /// Update the homescreen widget with the latest photo info
  Future<void> updateWidget({
    required String photoUrl,
    required String posterName,
    String? caption,
  }) async {
    if (kIsWeb) return; // Widgets are Android-only

    await HomeWidget.saveWidgetData<String>('photoUrl', photoUrl);
    await HomeWidget.saveWidgetData<String>('posterName', posterName);
    await HomeWidget.saveWidgetData<String>(
      'caption',
      caption ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'timestamp',
      DateTime.now().toIso8601String(),
    );

    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }
}
