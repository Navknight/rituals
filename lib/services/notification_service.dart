import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rituals/services/user_service.dart';
import 'package:rituals/services/widget_service.dart';
import 'package:go_router/go_router.dart';

class NotificationService {
  final _messaging = FirebaseMessaging.instance;
  final _userService = UserService();
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _localNotificationsInitialized = false;

  Future<void> initialize(String uid) async {
    if (kIsWeb) {
      // Web/iOS: don't auto-request permission — the app shows a banner
      // requiring a user gesture (required by iOS Safari PWA).
      // Only save the token if permission is already granted.
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _saveToken(uid);
      }
    } else {
      // Android: request permission automatically
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _saveToken(uid);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      _userService.updateFcmToken(uid, newToken);
    });

    // Initialize local notifications for Android
    if (!kIsWeb && !_localNotificationsInitialized) {
      await _initLocalNotifications();
      _localNotificationsInitialized = true;
    }
  }

  /// Call this from a user-gesture (button tap) on web/iOS.
  /// Returns true if permission was granted.
  Future<bool> requestWebPermission(String uid) async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
    if (granted) {
      await _saveToken(uid);
    }
    return granted;
  }

  /// Returns true if notification permission has not yet been asked on web.
  Future<bool> needsWebPermissionPrompt() async {
    if (!kIsWeb) return false;
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.notDetermined;
  }

  Future<void> _saveToken(String uid) async {
    final token = await _messaging.getToken(
      vapidKey: kIsWeb
          ? "BAba8TkdNMGYt0f5201ckALyBP4MMrWWFu5-oX_eoFzKUMV5QcfgzRRuztYKC6LHzK1VEk6yFtC8-E90pGtrx9Q"
          : null,
    );
    if (token != null) {
      await _userService.updateFcmToken(uid, token);
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Tap handling is done via FCM onMessageOpenedApp instead
      },
    );

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'rituals_photos',
      'Ritual Photos',
      description: 'Notifications when group members share photos',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Update widget
      if (message.data.containsKey('photoUrl')) {
        final widgetService = WidgetService();
        widgetService.updateWidget(
          photoUrl: message.data['photoUrl'] ?? '',
          posterName: message.notification?.body ?? 'New photo',
          caption: message.data['caption'],
        );
      }

      // Show local notification on Android (foreground messages don't show automatically)
      if (!kIsWeb) {
        _showLocalNotification(message);
      }
    });
  }

  void setupNotificationTapHandler(GoRouter router) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final groupId = message.data['groupId'];
      if (groupId != null) {
        router.go('/home/$groupId');
      }
    });

    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        final groupId = message.data['groupId'];
        if (groupId != null) {
          router.go('/home/$groupId');
        }
      }
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'rituals_photos',
      'Ritual Photos',
      channelDescription: 'Notifications when group members share photos',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'New photo!',
      body: notification.body ?? 'Someone shared a photo',
      notificationDetails: details,
      payload: message.data['groupId'],
    );
  }
}
