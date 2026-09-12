import 'package:firebase_auth/firebase_auth.dart';
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
}
