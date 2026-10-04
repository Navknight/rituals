import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Opens the Google account picker. The Firebase half is done by the
  /// `authenticationEvents` listener in main.dart, which is the same path the
  /// web sign-in button goes through: it upgrades an anonymous account in
  /// place when there is one, and signs in normally otherwise.
  Future<void> signInWithGoogle() => GoogleSignIn.instance.authenticate();

  /// Starts tracking straight away with no account. The data lives in Firebase
  /// under an anonymous uid and can be upgraded to a Google account later
  /// without losing anything.
  Future<UserCredential> signInAsGuest() =>
      FirebaseAuth.instance.signInAnonymously();

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nothing to sign out of when the session was a guest one.
    }
  }

  /// Deleting an account needs a fresh sign-in. Guests have nothing to prove;
  /// a Google account is asked to pick itself again, and picking a different
  /// one fails here, before any data has been touched.
  Future<void> reauthenticate() async {
    final user = currentUser;
    if (user == null || user.isAnonymous) return;
    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return;
    }
    final account = await GoogleSignIn.instance.authenticate();
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: account.authentication.idToken),
    );
  }
}
