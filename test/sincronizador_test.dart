import 'package:checkpoint_intensivo/data/local/visita_dao.dart';
import 'package:checkpoint_intensivo/data/sync/sincronizador.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/fakes.dart';

void main() {
  late VisitaDao dao;
  late RemotaFalsa remota;
  late Sincronizador sync;

  setUp(() async {
    dao = await daoDeTeste();
    remota = RemotaFalsa();
    sync = Sincronizador(dao: dao, remota: remota);
    await sync.iniciar();
  });

  tearDown(() => sync.dispose());

  test('EMPURRAR: pendente sobe e vira sincronizada', () async {
    await dao.salvar(visitaExemplo());

    final r = await sync.sincronizar();

    expect(r.enviadas, 1);
    expect(remota.docs, contains('v1'));
    expect((await dao.buscar('v1'))!.sincronizada, isTrue);
    expect(sync.pendentes, 0);
    expect(sync.ultimaSincronizacao, isNotNull);
  });

  test(
    'CONCORRÊNCIA: chamar durante uma rodada espera a fila esvaziar',
    () async {
      await dao.salvar(visitaExemplo(id: 'a'));
      final primeira = sync.sincronizar();
      // escrita nova enquanto a primeira rodada está no ar
      await dao.salvar(visitaExemplo(id: 'b'));
      final segunda = sync.sincronizar();

      expect(identical(primeira, segunda), isTrue);
      await segunda;
      expect(sync.pendentes, 0);
      expect(remota.docs.keys, containsAll(['a', 'b']));
    },
  );

  test('OFFLINE: falha não perde nada, a visita continua na fila', () async {
    await dao.salvar(visitaExemplo());
    remota.offline = true;

    final r = await sync.sincronizar();

    expect(r.falhou, isTrue);
    expect(sync.estado, EstadoSync.erro);
    expect(sync.pendentes, 1);

    remota.offline = false; // a rede voltou
    await sync.sincronizar();
    expect(sync.pendentes, 0);
  });

  test('PUXAR: visita criada em outro aparelho aparece aqui', () async {
    remota.gravarDireto(visitaExemplo(id: 'v9', titulo: 'Do tablet'));

    final r = await sync.sincronizar();

    expect(r.recebidas, 1);
    expect((await dao.buscar('v9'))!.titulo, 'Do tablet');
  });

  test('PUXAR é incremental: a segunda rodada não traz de novo', () async {
    remota.gravarDireto(visitaExemplo(id: 'v9'));
    await sync.sincronizar();

    final r = await sync.sincronizar();

    expect(r.recebidas, 0);
  });

  test('EXCLUSÃO propaga: lápide sobe e a linha some do aparelho', () async {
    await dao.salvar(visitaExemplo(sincronizada: true));
    await dao.salvar(
      visitaExemplo(excluida: true, atualizadaEm: DateTime(2026, 11, 10, 11)),
    );

    await sync.sincronizar();

    expect(remota.docs['v1']!.visita.excluida, isTrue);
    expect(await dao.buscar('v1'), isNull);
  });

  test('EXCLUSÃO vinda do servidor apaga aqui', () async {
    await dao.salvar(visitaExemplo(sincronizada: true));
    remota.gravarDireto(
      visitaExemplo(excluida: true, atualizadaEm: DateTime(2026, 11, 10, 12)),
    );

    await sync.sincronizar();

    expect(await dao.buscar('v1'), isNull);
  });

  group('CONFLITO (last-write-wins por atualizadaEm)', () {
    // O aparelho estava offline e editou; enquanto isso, outra pessoa
    // editou a mesma visita direto no servidor.
    Future<void> prepararConflito({
      required DateTime local,
      required DateTime servidor,
    }) async {
      await dao.salvar(visitaExemplo(sincronizada: true));
      await dao.salvar(
        visitaExemplo(titulo: 'Versão do aparelho', atualizadaEm: local),
      );
      remota.gravarDireto(
        visitaExemplo(titulo: 'Versão do servidor', atualizadaEm: servidor),
      );
    }

    test('servidor mais recente vence; aparelho adota a versão dele', () async {
      await prepararConflito(
        local: DateTime(2026, 11, 10, 10),
        servidor: DateTime(2026, 11, 10, 11),
      );

      final r = await sync.sincronizar();

      expect(r.conflitos, 1);
      expect(r.enviadas, 0); // nada a empurrar: a local foi descartada
      expect((await dao.buscar('v1'))!.titulo, 'Versão do servidor');
      expect(remota.docs['v1']!.visita.titulo, 'Versão do servidor');
    });

    test('aparelho mais recente vence e sobrescreve o servidor', () async {
      await prepararConflito(
        local: DateTime(2026, 11, 10, 12),
        servidor: DateTime(2026, 11, 10, 11),
      );

      final r = await sync.sincronizar();

      expect(r.conflitos, 1);
      expect(r.enviadas, 1);
      expect(remota.docs['v1']!.visita.titulo, 'Versão do aparelho');
      expect((await dao.buscar('v1'))!.sincronizada, isTrue);
    });
  });
}
