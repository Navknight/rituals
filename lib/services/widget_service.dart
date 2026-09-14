import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Feeds the Android home screen widget.
///
/// There is no iOS widget extension in this project yet, so every call is a
/// no-op there as well as on web.
class WidgetService {
  static const _androidWidgetName = 'RitualWidgetProvider';
  static const _todayWidgetName = 'TodayWidgetProvider';
  static const _streakWidgetName = 'StreakWidgetProvider';
  static const _appGroupId = 'group.com.rituals.android';

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

  /// Feeds the "today" and "streak" home screen widgets.
  Future<void> updateSummary({
    required String space,
    required int done,
    required int due,
    required List<String> lines,
    required int topStreak,
    required String topStreakRitual,
  }) async {
    if (!_supported) return;
    try {
      await HomeWidget.saveWidgetData<String>('todaySpace', space);
      await HomeWidget.saveWidgetData<String>('todayDone', '$done');
      await HomeWidget.saveWidgetData<String>('todayDue', '$due');
      await HomeWidget.saveWidgetData<String>('todayLines', lines.join('\n'));
      await HomeWidget.saveWidgetData<String>('topStreak', '$topStreak');
      await HomeWidget.saveWidgetData<String>('topStreakRitual', topStreakRitual);
      await HomeWidget.updateWidget(androidName: _todayWidgetName);
      await HomeWidget.updateWidget(androidName: _streakWidgetName);
    } catch (e) {
      debugPrint('[WidgetService] summary update failed: $e');
    }
  }
}
