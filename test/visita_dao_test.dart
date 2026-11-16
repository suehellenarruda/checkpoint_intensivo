import 'package:checkpoint_intensivo/data/local/visita_dao.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/fakes.dart';

void main() {
  late VisitaDao dao;

  setUp(() async => dao = await daoDeTeste());

  test('salvar e listar (CREATE + READ)', () async {
    await dao.salvar(visitaExemplo());
    final lista = await dao.listar();
    expect(lista, hasLength(1));
    expect(lista.single.titulo, 'Vistoria');
  });

  test('salvar com o mesmo id substitui (UPDATE)', () async {
    await dao.salvar(visitaExemplo());
    await dao.salvar(visitaExemplo(titulo: 'Vistoria final'));
    expect((await dao.listar()).single.titulo, 'Vistoria final');
  });

  test('excluída logicamente some da lista mas continua na fila', () async {
    await dao.salvar(visitaExemplo(excluida: true));
    expect(await dao.listar(), isEmpty);
    expect(await dao.pendentes(), hasLength(1));
  });

  test('apagarDeVez remove a linha (DELETE)', () async {
    await dao.salvar(visitaExemplo());
    await dao.apagarDeVez('v1');
    expect(await dao.buscar('v1'), isNull);
  });

  test('marcarSincronizada respeita edição feita durante o envio', () async {
    final enviada = visitaExemplo();
    await dao.salvar(enviada);
    // usuário editou enquanto o upload estava no ar
    await dao.salvar(
      visitaExemplo(
        titulo: 'Editada',
        atualizadaEm: DateTime(2026, 11, 10, 10),
      ),
    );

    final marcou = await dao.marcarSincronizada(enviada);

    expect(marcou, isFalse);
    expect(await dao.contarPendentes(), 1);
  });

  test('tabela meta guarda e lê valores', () async {
    await dao.gravarMeta('k', '42');
    expect(await dao.lerMeta('k'), '42');
    expect(await dao.lerMeta('inexistente'), isNull);
  });
}
