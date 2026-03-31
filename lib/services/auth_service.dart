import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  Future<User> ensureAnonymousSession() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      return currentUser;
    }

    final credential = await _firebaseAuth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Anonymous authentication failed.');
    }
    return user;
  }
}
