import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Serviço de autenticação (login/logout)
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Usuário atualmente logado (null se não logado)
  User? get currentUser => _auth.currentUser;

  /// Stream que emite eventos quando o usuário loga ou desloga
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Faz login com conta Google
  /// Retorna o usuário logado ou null se cancelou
  Future<User?> signInWithGoogle() async {
    try {
      // Abre a tela de escolha da conta Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Usuário cancelou o login
      if (googleUser == null) return null;

      // Obtém as credenciais da conta Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Cria credencial do Firebase com as infos do Google
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Faz login no Firebase
      final UserCredential result =
          await _auth.signInWithCredential(credential);

      return result.user;
    } catch (e) {
      print('Erro no login com Google: $e');
      return null;
    }
  }

  /// Faz logout do app
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Nome de exibição do usuário atual
  String get displayName => currentUser?.displayName ?? 'Usuário';

  /// Foto de perfil do usuário atual
  String? get photoUrl => currentUser?.photoURL;

  /// ID único do usuário atual
  String get userId => currentUser?.uid ?? '';
}
