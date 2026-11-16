import 'package:uuid/uuid.dart';

import '../../domain/models/status_visita.dart';
import '../../domain/models/visita.dart';
import '../local/visita_dao.dart';

/// A ÚNICA porta da UI para os dados de visitas.
///
/// Versão do Encontro 01: tudo fica no SQLite. Toda escrita já marca
/// `sincronizada = false` — no Encontro 02 o Sincronizador lê essa
/// marca para saber o que subir.
class VisitaRepository {
  VisitaRepository(this._dao, {DateTime Function()? relogio})
    : _relogio = relogio ?? DateTime.now;

  final VisitaDao _dao;
  static const _uuid = Uuid();
  final DateTime Function() _relogio;

  Future<List<Visita>> listar() => _dao.listar();

  Future<Visita> criar({
    required String titulo,
    required String cliente,
    required String endereco,
    required DateTime agendadaPara,
    StatusVisita status = StatusVisita.agendada,
    String? observacoes,
  }) async {
    final agora = _relogio();
    final visita = Visita(
      // id gerado NO APARELHO: dá para criar offline, sem esperar o servidor
      id: _uuid.v4(),
      titulo: titulo.trim(),
      cliente: cliente.trim(),
      endereco: endereco.trim(),
      status: status,
      agendadaPara: agendadaPara,
      observacoes: _limpar(observacoes),
      criadaEm: agora,
      atualizadaEm: agora,
    );
    await _dao.salvar(visita);
    return visita;
  }

  Future<void> atualizar(Visita visita) async {
    await _dao.salvar(
      visita.copyWith(
        titulo: visita.titulo.trim(),
        cliente: visita.cliente.trim(),
        endereco: visita.endereco.trim(),
        observacoes: () => _limpar(visita.observacoes),
        atualizadaEm: _relogio(),
        sincronizada: false,
      ),
    );
  }

  /// Encontro 01: exclusão FÍSICA (DELETE). No Encontro 02 ela vira
  /// exclusão lógica ("lápide"), para a exclusão chegar ao servidor.
  Future<void> excluir(Visita visita) => _dao.apagarDeVez(visita.id);

  static String? _limpar(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
