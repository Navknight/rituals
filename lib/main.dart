import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rituals/app/router.dart';
import 'package:rituals/app/theme.dart';
import 'package:rituals/services/notification_service.dart';
import 'package:rituals/services/widget_service.dart';
import 'firebase_options.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Update homescreen widget with the new photo data
  if (message.data.containsKey('photoUrl')) {
    final widgetService = WidgetService();
    await widgetService.updateWidget(
      photoUrl: message.data['photoUrl'] ?? '',
      posterName: message.notification?.body ?? 'New photo',
      caption: message.data['caption'],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[main] Starting app...');

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[main] Firebase initialized');
  } catch (e) {
    debugPrint('[main] Firebase init FAILED: $e');
  }

  // FCM background handler (no-op on web)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Set up auth event listener BEFORE calling initialize()
  GoogleSignIn.instance.authenticationEvents.listen((event) async {
    debugPrint('[main] authenticationEvent: ${event.runtimeType}');
    if (event case GoogleSignInAuthenticationEventSignIn(:final user)) {
      try {
        final idToken = user.authentication.idToken;
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        await FirebaseAuth.instance.signInWithCredential(credential);
        debugPrint('[main] signInWithCredential succeeded');
      } catch (e) {
        debugPrint('[main] signInWithCredential FAILED: $e');
      }
    }
  });

  // Initialize FCM after auth is ready
  FirebaseAuth.instance.authStateChanges().listen((user) {
    debugPrint('[main] authStateChanges: user=${user?.uid}');
    if (user != null) {
      try {
        final notificationService = NotificationService();
        notificationService.initialize(user.uid);
        notificationService.setupForegroundHandler();
        notificationService.setupNotificationTapHandler(router);
      } catch (e) {
        debugPrint('[main] NotificationService init FAILED: $e');
      }
    }
  });

  // Run app immediately — don't block on GoogleSignIn.initialize()
  // GIS script loads async; auth events will fire once it's ready
  debugPrint('[main] runApp');
  runApp(const ProviderScope(child: RitualsApp()));

  // Initialize GoogleSignIn in background after app is running
  GoogleSignIn.instance.initialize(
    clientId:
        '637686614153-t097c2sv88tpnk7josd88t0bur78kao6.apps.googleusercontent.com',
    serverClientId: kIsWeb
        ? null
        : '637686614153-t097c2sv88tpnk7josd88t0bur78kao6.apps.googleusercontent.com',
  ).then((_) {
    debugPrint('[main] GoogleSignIn initialized');
  }).catchError((e) {
    debugPrint('[main] GoogleSignIn init FAILED: $e');
  });
}

class RitualsApp extends ConsumerWidget {
  const RitualsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: "Rituals",
      theme: appTheme(),
      routerConfig: router,
    );
  }
}
