import '../domain/models/usuario.dart';
import 'local/database.dart';
import 'local/visita_dao.dart';
import 'repositories/visita_repository.dart';

/// Tudo que existe enquanto UM usuário está logado.
///
/// Nasce no login, morre no logout. Assim é impossível o usuário B
/// enxergar o banco do usuário A.
///
/// Versão do Encontro 01: só banco local. No Encontro 02 a sessão ganha
/// o Sincronizador, o Firestore e o monitor de conectividade.
class Sessao {
  Sessao._(this.usuario, this._banco, this.repositorio);

  final Usuario usuario;
  final AppDatabase _banco;
  final VisitaRepository repositorio;

  static Future<Sessao> abrir(Usuario usuario) async {
    final banco = await AppDatabase.abrir(usuario.uid);
    final dao = VisitaDao(banco.db);
    return Sessao._(usuario, banco, VisitaRepository(dao));
  }

  /// Fecha a sessão. Com [apagarDados], remove o banco do aparelho
  /// (minimização: o próximo a usar o celular não herda nada).
  Future<void> encerrar({bool apagarDados = true}) async {
    if (apagarDados) {
      await _banco.apagar();
    } else {
      await _banco.fechar();
    }
  }
}
