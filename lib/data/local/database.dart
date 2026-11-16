import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Abre (ou cria) o banco local de UM usuário.
///
/// Um arquivo por usuário: `checkpoint_<uid>.db`. Se duas pessoas usam o
/// mesmo aparelho, uma nunca lê as visitas da outra — e o logout pode
/// apagar o arquivo inteiro.
class AppDatabase {
  AppDatabase._(this.db, this.caminho);

  final Database db;
  final String caminho;

  static const versao = 1;

  static Future<AppDatabase> abrir(
    String uid, {
    DatabaseFactory? factory,
    String? caminhoFixo,
  }) async {
    final f = factory ?? databaseFactory;
    final caminho =
        caminhoFixo ?? p.join(await f.getDatabasesPath(), nomeArquivo(uid));
    final db = await f.openDatabase(
      caminho,
      options: OpenDatabaseOptions(version: versao, onCreate: _criar),
    );
    return AppDatabase._(db, caminho);
  }

  static String nomeArquivo(String uid) {
    // uid vem do Firebase, mas nome de arquivo nunca confia em entrada.
    final seguro = uid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'checkpoint_$seguro.db';
  }

  static Future<void> _criar(Database db, int versao) async {
    await db.execute('''
      CREATE TABLE visitas (
        id             TEXT PRIMARY KEY,
        titulo         TEXT    NOT NULL,
        cliente        TEXT    NOT NULL,
        endereco       TEXT    NOT NULL,
        status         TEXT    NOT NULL,
        agendada_para  INTEGER NOT NULL,
        observacoes    TEXT,
        criada_em      INTEGER NOT NULL,
        atualizada_em  INTEGER NOT NULL,
        sincronizada   INTEGER NOT NULL DEFAULT 0,
        excluida       INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_visitas_sincronizada ON visitas(sincronizada)',
    );
    await db.execute(
      'CREATE INDEX idx_visitas_agendada ON visitas(agendada_para)',
    );
    // Pares chave-valor do sincronizador (último pull, última sync).
    await db.execute('''
      CREATE TABLE meta (
        chave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');
  }

  Future<void> fechar() => db.close();

  /// Fecha e APAGA o arquivo. Usado no logout.
  Future<void> apagar({DatabaseFactory? factory}) async {
    await db.close();
    await (factory ?? databaseFactory).deleteDatabase(caminho);
  }
}
