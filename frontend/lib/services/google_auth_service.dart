import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '872525914233-mqhltrhb1d7vka3jdko1lget4trcbe5e.apps.googleusercontent.com',
    scopes: ['email', 'profile', 'openid'],
  );

  static Future<AuthResult> signIn() async {
    try {
      // Force account picker every time
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        return AuthResult.failure('Google sign in cancelled');
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        return AuthResult.failure('Failed to get Google ID token');
      }

      return await ApiService.googleLogin(idToken: idToken);

    } catch (e) {
      return AuthResult.failure('Google sign in failed: $e');
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}