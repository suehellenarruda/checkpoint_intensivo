import 'package:flutter/foundation.dart';

import '../../data/auth/auth_service.dart';

enum ModoLogin { entrar, cadastrar }

/// Estado da tela de login. Não conhece widget nenhum: dá para testar puro.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._auth, {DateTime Function()? relogio})
    : _relogio = relogio ?? DateTime.now;

  final AuthService _auth;
  final DateTime Function() _relogio;

  /// Depois de [maxFalhas] erros seguidos, o botão trava por [espera].
  /// O servidor também limita; isto só poupa requisições e desestimula
  /// tentativa e erro na mão.
  static const maxFalhas = 5;
  static const espera = Duration(seconds: 30);

  ModoLogin modo = ModoLogin.entrar;
  bool enviando = false;
  String? erro;
  String? aviso;
  int _falhas = 0;
  DateTime? _bloqueadoAte;

  bool get bloqueado =>
      _bloqueadoAte != null && _relogio().isBefore(_bloqueadoAte!);

  int get segundosRestantes =>
      bloqueado ? _bloqueadoAte!.difference(_relogio()).inSeconds + 1 : 0;

  void alternarModo() {
    modo = modo == ModoLogin.entrar ? ModoLogin.cadastrar : ModoLogin.entrar;
    erro = null;
    aviso = null;
    notifyListeners();
  }

  /// Devolve `true` se autenticou. Quem navega é o AuthGate, que escuta
  /// o `authStateChanges` — a tela de login não decide para onde ir.
  Future<bool> enviar(String email, String senha) async {
    if (enviando || bloqueado) return false; // sem duplo clique
    enviando = true;
    erro = null;
    aviso = null;
    notifyListeners();
    try {
      if (modo == ModoLogin.entrar) {
        await _auth.entrar(email: email, senha: senha);
      } else {
        await _auth.cadastrar(email: email, senha: senha);
      }
      _falhas = 0;
      return true;
    } on FalhaAuth catch (f) {
      erro = f.mensagem;
      _falhas++;
      if (_falhas >= maxFalhas) {
        _bloqueadoAte = _relogio().add(espera);
        _falhas = 0;
      }
      return false;
    } finally {
      enviando = false;
      notifyListeners();
    }
  }

  Future<void> esqueciSenha(String email) async {
    erro = null;
    try {
      await _auth.redefinirSenha(email: email);
      // Mesma frase exista o e-mail ou não.
      aviso = 'Se houver uma conta com esse e-mail, enviaremos um link.';
    } on FalhaAuth catch (f) {
      erro = f.mensagem;
    }
    notifyListeners();
  }
}
