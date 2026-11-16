import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/usuario.dart';
import 'auth_service.dart';

/// Implementação real com Firebase Authentication.
///
/// O que o Firebase já resolve por nós (e não devemos reinventar):
/// - a senha nunca é guardada no aparelho; o servidor guarda só o hash;
/// - o token de sessão (JWT de 1h) é renovado sozinho com o refresh token;
/// - a sessão fica guardada no armazenamento seguro da plataforma;
/// - limite de tentativas no servidor (`too-many-requests`).
class AuthFirebase implements AuthService {
  AuthFirebase(this._auth);

  final FirebaseAuth _auth;

  static Usuario? _converter(User? u) =>
      u == null ? null : Usuario(uid: u.uid, email: u.email ?? '');

  @override
  Stream<Usuario?> get usuario => _auth.authStateChanges().map(_converter);

  @override
  Usuario? get atual => _converter(_auth.currentUser);

  @override
  Future<void> entrar({required String email, required String senha}) =>
      _executar(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: senha,
        ),
      );

  @override
  Future<void> cadastrar({required String email, required String senha}) =>
      _executar(
        () => _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: senha,
        ),
        cadastro: true,
      );

  @override
  Future<void> redefinirSenha({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Engolimos de propósito: responder "esse e-mail não existe"
      // entregaria a lista de usuários para quem tentar adivinhar.
      if (e.code == 'network-request-failed') throw FalhaAuth.semConexao;
      if (e.code == 'too-many-requests') throw FalhaAuth.muitasTentativas;
    }
  }

  @override
  Future<void> revalidarSessao() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      await u.reload();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-disabled':
        case 'user-not-found':
        case 'user-token-expired':
        case 'invalid-user-token':
          // Conta revogada no servidor: derruba a sessão local.
          await _auth.signOut();
        default:
          // Sem rede ou erro passageiro: segue offline com a sessão salva.
          break;
      }
    }
  }

  @override
  Future<void> sair() => _auth.signOut();

  Future<void> _executar(
    Future<UserCredential> Function() acao, {
    bool cadastro = false,
  }) async {
    try {
      await acao();
    } on FirebaseAuthException catch (e) {
      // Log só do CÓDIGO, nunca do e-mail nem da senha.
      debugPrint('[auth] falhou: ${e.code}');
      throw _traduzir(e.code, cadastro: cadastro);
    }
  }

  static FalhaAuth _traduzir(String code, {required bool cadastro}) {
    switch (code) {
      case 'invalid-credential':
      case 'invalid-email':
      case 'wrong-password':
      case 'user-not-found':
      case 'user-disabled':
        // Mesma mensagem para todos: não revela se o e-mail existe.
        return cadastro
            ? FalhaAuth.cadastroRecusado
            : FalhaAuth.credenciaisInvalidas;
      case 'email-already-in-use':
      case 'weak-password':
        return FalhaAuth.cadastroRecusado;
      case 'too-many-requests':
        return FalhaAuth.muitasTentativas;
      case 'network-request-failed':
        return FalhaAuth.semConexao;
      default:
        return FalhaAuth.generica;
    }
  }
}
