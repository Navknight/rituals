import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rituals/app/router.dart';
import 'package:rituals/app/theme.dart';
import 'package:rituals/core/settings_provider.dart';
import 'package:rituals/services/notification_service.dart';
import 'package:rituals/services/widget_service.dart';

import 'firebase_options.dart';

/// Run against the local Firebase emulators with
/// `flutter run --dart-define=USE_EMULATOR=true`.
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');
const _emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: 'localhost',
);

const _googleClientId =
    '637686614153-t097c2sv88tpnk7josd88t0bur78kao6.apps.googleusercontent.com';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (message.data.containsKey('photoUrl')) {
    await WidgetService().updateWidget(
      photoUrl: message.data['photoUrl'] ?? '',
      posterName: message.notification?.body ?? 'New photo',
      caption: message.data['caption'],
    );
  }
}

/// reCAPTCHA v3 site key for App Check on web. Pass it at build time with
/// --dart-define=RECAPTCHA_SITE_KEY=... ; App Check is skipped on web without
/// it so a local build still runs.
const _recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// Blocks requests that do not come from a genuine build of this app, so a
/// leaked API key cannot be used to run up the project's bill.
Future<void> _activateAppCheck() async {
  try {
    if (kIsWeb && _recaptchaSiteKey.isEmpty) {
      debugPrint('[main] App Check skipped on web: no reCAPTCHA site key.');
      return;
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid:
          kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? AppleDebugProvider() : AppleAppAttestProvider(),
      providerWeb:
          kIsWeb ? ReCaptchaV3Provider(_recaptchaSiteKey) : null,
    );
  } catch (e) {
    // Never block startup on App Check.
    debugPrint('[main] App Check activation failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (_useEmulator) {
      FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
      await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
      await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, 9199);
    } else {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      await _activateAppCheck();
    }
  } catch (e) {
    debugPrint('[main] Firebase init failed: $e');
  }

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // Without this the widget cannot read anything the app saves.
    await WidgetService().initialize();
  }

  GoogleSignIn.instance.authenticationEvents.listen((event) async {
    if (event case GoogleSignInAuthenticationEventSignIn(:final user)) {
      try {
        final credential = GoogleAuthProvider.credential(
          idToken: user.authentication.idToken,
        );
        final current = FirebaseAuth.instance.currentUser;
        // Keep a guest's rituals by upgrading the anonymous account in place.
        if (current != null && current.isAnonymous) {
          try {
            await current.linkWithCredential(credential);
            return;
          } on FirebaseAuthException catch (e) {
            if (e.code != 'credential-already-in-use' &&
                e.code != 'email-already-in-use') {
              rethrow;
            }
          }
        }
        await FirebaseAuth.instance.signInWithCredential(credential);
      } catch (e) {
        debugPrint('[main] Google sign-in failed: $e');
      }
    }
  });

  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user == null) return;
    try {
      final notifications = NotificationService();
      notifications.initialize(user.uid);
      notifications.setupForegroundHandler();
    } catch (e) {
      debugPrint('[main] Notification setup failed: $e');
    }
  });

  runApp(const ProviderScope(child: RitualsApp()));

  GoogleSignIn.instance
      .initialize(
        clientId: _googleClientId,
        serverClientId: kIsWeb ? null : _googleClientId,
      )
      .catchError((Object e) => debugPrint('[main] GoogleSignIn init: $e'));
}

class RitualsApp extends ConsumerWidget {
  const RitualsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Rituals',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildTheme(settings.accent, Brightness.light),
      darkTheme: buildTheme(settings.accent, Brightness.dark),
      home: const AppRoot(),
    );
  }
}
