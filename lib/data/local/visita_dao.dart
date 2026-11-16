import 'package:sqflite/sqflite.dart';

import '../../domain/models/visita.dart';

/// Único lugar do app que escreve SQL de visitas.
class VisitaDao {
  VisitaDao(this._db);

  final Database _db;

  /// Visitas visíveis (sem as excluídas logicamente), por data.
  Future<List<Visita>> listar() async {
    final linhas = await _db.query(
      'visitas',
      where: 'excluida = 0',
      orderBy: 'agendada_para ASC',
    );
    return linhas.map(Visita.fromMap).toList();
  }

  Future<Visita?> buscar(String id) async {
    final linhas = await _db.query(
      'visitas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return linhas.isEmpty ? null : Visita.fromMap(linhas.first);
  }

  /// Insere ou substitui (mesmo `id`).
  Future<void> salvar(Visita v) => _db.insert(
    'visitas',
    v.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> apagarDeVez(String id) =>
      _db.delete('visitas', where: 'id = ?', whereArgs: [id]);

  /// A fila de sincronização é só um WHERE.
  Future<List<Visita>> pendentes() async {
    final linhas = await _db.query(
      'visitas',
      where: 'sincronizada = 0',
      orderBy: 'atualizada_em ASC',
    );
    return linhas.map(Visita.fromMap).toList();
  }

  Future<int> contarPendentes() async {
    final r = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM visitas WHERE sincronizada = 0',
    );
    return (r.first['n'] as int?) ?? 0;
  }

  /// Marca como enviada SÓ se ninguém editou a visita durante o envio.
  ///
  /// Sem o `atualizada_em = ?`, uma edição feita enquanto o upload estava
  /// no ar seria marcada como sincronizada e nunca subiria.
  /// Devolve `true` se marcou.
  Future<bool> marcarSincronizada(Visita enviada) async {
    final n = await _db.update(
      'visitas',
      {'sincronizada': 1},
      where: 'id = ? AND atualizada_em = ?',
      whereArgs: [enviada.id, enviada.atualizadaEm.millisecondsSinceEpoch],
    );
    return n == 1;
  }

  // ── tabela meta ──

  Future<String?> lerMeta(String chave) async {
    final r = await _db.query(
      'meta',
      where: 'chave = ?',
      whereArgs: [chave],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['valor'] as String;
  }

  Future<void> gravarMeta(String chave, String valor) => _db.insert('meta', {
    'chave': chave,
    'valor': valor,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
