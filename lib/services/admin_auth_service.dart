import 'package:firebase_auth/firebase_auth.dart';

class AdminAuthService {
  AdminAuthService._(this._firebaseAuth);

  static final AdminAuthService instance = AdminAuthService._(
    FirebaseAuth.instance,
  );

  final FirebaseAuth _firebaseAuth;

  static const String adminEmail = 'admin@lohiyaai.com';
  static const String adminPassword = 'admin@lohiya';

  Future<bool> isLoggedIn() async {
    final user = _firebaseAuth.currentUser;
    return user != null && user.email?.toLowerCase() == adminEmail;
  }

  Future<String?> currentAdminName() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }
    return user.displayName ?? user.email;
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = credential.user;
      if (user == null) {
        return 'Admin sign-in failed. Please try again.';
      }
      if (user.email?.toLowerCase() != adminEmail) {
        await _firebaseAuth.signOut();
        return 'This account is not allowed to access the admin panel.';
      }
      return null;
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-email':
          return 'Invalid admin email or password.';
        case 'too-many-requests':
          return 'Too many login attempts. Please wait a bit and try again.';
        default:
          return error.message ?? 'Admin sign-in failed.';
      }
    }
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }
}
