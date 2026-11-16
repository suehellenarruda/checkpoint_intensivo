import 'dart:async';
import 'dart:io';

import 'package:checkpoint_intensivo/data/auth/auth_service.dart';
import 'package:checkpoint_intensivo/data/local/database.dart';
import 'package:checkpoint_intensivo/data/local/visita_dao.dart';
import 'package:checkpoint_intensivo/domain/models/status_visita.dart';
import 'package:checkpoint_intensivo/domain/models/usuario.dart';
import 'package:checkpoint_intensivo/domain/models/visita.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Banco SQLite REAL rodando no computador (sem celular), num arquivo
/// temporário novo a cada teste — um teste nunca enxerga dados de outro.
Future<VisitaDao> daoDeTeste() async {
  sqfliteFfiInit();
  final pasta = Directory.systemTemp.createTempSync('checkpoint_teste_');
  final banco = await AppDatabase.abrir(
    'teste',
    factory: databaseFactoryFfi,
    caminhoFixo: '${pasta.path}/teste.db',
  );
  return VisitaDao(banco.db);
}

Visita visitaExemplo({
  String id = 'v1',
  String titulo = 'Vistoria',
  DateTime? atualizadaEm,
  bool sincronizada = false,
  bool excluida = false,
}) {
  final t = atualizadaEm ?? DateTime(2026, 11, 10, 9);
  return Visita(
    id: id,
    titulo: titulo,
    cliente: 'ACME',
    endereco: 'Rua A, 1',
    status: StatusVisita.agendada,
    agendadaPara: DateTime(2026, 11, 12, 14),
    criadaEm: DateTime(2026, 11, 10, 8),
    atualizadaEm: t,
    sincronizada: sincronizada,
    excluida: excluida,
  );
}

class AuthFalsa implements AuthService {
  final _controle = StreamController<Usuario?>.broadcast();
  Usuario? _atual;
  final senhas = <String, String>{};
  int chamadas = 0;

  @override
  Stream<Usuario?> get usuario => _controle.stream;

  @override
  Usuario? get atual => _atual;

  @override
  Future<void> entrar({required String email, required String senha}) async {
    chamadas++;
    if (senhas[email] != senha) throw FalhaAuth.credenciaisInvalidas;
    _atual = Usuario(uid: 'uid-$email', email: email);
    _controle.add(_atual);
  }

  @override
  Future<void> cadastrar({required String email, required String senha}) async {
    chamadas++;
    if (senhas.containsKey(email)) throw FalhaAuth.cadastroRecusado;
    senhas[email] = senha;
    await entrar(email: email, senha: senha);
  }

  @override
  Future<void> redefinirSenha({required String email}) async {}

  @override
  Future<void> revalidarSessao() async {}

  @override
  Future<void> sair() async {
    _atual = null;
    _controle.add(null);
  }
}
