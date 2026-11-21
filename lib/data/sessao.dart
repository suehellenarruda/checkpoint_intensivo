import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/models/usuario.dart';
import 'local/database.dart';
import 'local/visita_dao.dart';
import 'remote/visita_firestore.dart';
import 'repositories/visita_repository.dart';
import 'sync/sincronizador.dart';

/// Tudo que existe enquanto UM usuário está logado.
///
/// Nasce no login, morre no logout. Assim é impossível o usuário B
/// enxergar o banco, a fila ou o sincronizador do usuário A.
class Sessao {
  Sessao._(this.usuario, this._banco, this.repositorio, this.sincronizador);

  final Usuario usuario;
  final AppDatabase _banco;
  final VisitaRepository repositorio;
  final Sincronizador sincronizador;

  static Future<Sessao> abrir(
    Usuario usuario, {
    required FirebaseFirestore firestore,
    Connectivity? connectivity,
  }) async {
    final banco = await AppDatabase.abrir(usuario.uid);
    final dao = VisitaDao(banco.db);
    final conn = connectivity ?? Connectivity();

    final sync = Sincronizador(
      dao: dao,
      remota: VisitaFirestore(firestore, usuario.uid),
      conectividade: conn.onConnectivityChanged.map(_temRede).distinct(),
    );
    await sync.iniciar();
    final temRede = _temRede(await conn.checkConnectivity());
    sync.informarConectividade(temRede);

    final sessao = Sessao._(usuario, banco, VisitaRepository(dao, sync), sync);
    // Primeira sincronização ao abrir, se houver rede.
    if (temRede) unawaited(sync.sincronizar());
    return sessao;
  }

  static bool _temRede(List<ConnectivityResult> r) =>
      r.isNotEmpty && !r.contains(ConnectivityResult.none);

  /// Fecha a sessão. Com [apagarDados], remove o banco do aparelho
  /// (minimização: o próximo a usar o celular não herda nada).
  Future<void> encerrar({bool apagarDados = true}) async {
    sincronizador.dispose();
    if (apagarDados) {
      await _banco.apagar();
    } else {
      await _banco.fechar();
    }
  }
}
