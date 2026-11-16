import '../../domain/models/usuario.dart';

/// Contrato de autenticação. A UI e os testes dependem DISTO,
/// não do Firebase — veja `auth_firebase.dart` para a implementação real.
abstract interface class AuthService {
  /// Emite o usuário logado, ou `null` depois do logout.
  Stream<Usuario?> get usuario;

  Usuario? get atual;

  Future<void> entrar({required String email, required String senha});

  Future<void> cadastrar({required String email, required String senha});

  /// Sempre "dá certo" do ponto de vista da tela, exista o e-mail ou não.
  Future<void> redefinirSenha({required String email});

  /// Pergunta ao servidor se a sessão ainda vale (conta desativada,
  /// senha trocada em outro aparelho...). Sem rede, não faz nada:
  /// offline confiamos na sessão guardada.
  Future<void> revalidarSessao();

  Future<void> sair();
}

/// Falha de autenticação com mensagem PRONTA para a tela.
/// Nunca carrega detalhe técnico, nem diz se o e-mail existe.
class FalhaAuth implements Exception {
  const FalhaAuth(this.mensagem);

  final String mensagem;

  static const credenciaisInvalidas = FalhaAuth('E-mail ou senha inválidos.');
  static const muitasTentativas = FalhaAuth(
    'Muitas tentativas. Aguarde alguns minutos e tente de novo.',
  );
  static const semConexao = FalhaAuth(
    'Sem conexão. O primeiro login precisa de internet.',
  );
  static const cadastroRecusado = FalhaAuth(
    'Não foi possível criar a conta com esses dados.',
  );
  static const generica = FalhaAuth(
    'Não foi possível concluir. Tente de novo.',
  );

  @override
  String toString() => 'FalhaAuth($mensagem)';
}
