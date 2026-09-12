import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: googleUser.authentication.idToken,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  /// Starts tracking straight away with no account. The data lives in Firebase
  /// under an anonymous uid and can be upgraded to a Google account later
  /// without losing anything.
  Future<UserCredential> signInAsGuest() =>
      FirebaseAuth.instance.signInAnonymously();

  /// Attaches a Google account to the current guest session, keeping the same
  /// uid so rituals and streaks carry over.
  Future<UserCredential?> linkGuestToGoogle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) return signInWithGoogle();

    final googleUser = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: googleUser.authentication.idToken,
    );

    try {
      return await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      // The Google account already has its own data; sign into that instead of
      // failing, and let the guest data go.
      if (e.code == 'credential-already-in-use' ||
          e.code == 'email-already-in-use') {
        return FirebaseAuth.instance.signInWithCredential(credential);
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nothing to sign out of when the session was a guest one.
    }
  }
}
