import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/models/status_visita.dart';
import '../../domain/models/visita.dart';
import '../local/visita_dao.dart';
import '../sync/sincronizador.dart';

/// A ÚNICA porta da UI para os dados de visitas.
///
/// Toda escrita segue o mesmo roteiro offline-first:
/// grava no SQLite com `sincronizada = false` → a tela já mostra →
/// pede ao sincronizador para tentar subir (sem esperar).
class VisitaRepository {
  VisitaRepository(this._dao, this._sync, {DateTime Function()? relogio})
    : _relogio = relogio ?? DateTime.now;

  final VisitaDao _dao;
  final Sincronizador _sync;
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
    await _aposEscrita();
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
    await _aposEscrita();
  }

  /// Exclusão LÓGICA: vira lápide pendente. O sincronizador sobe a lápide
  /// e só então apaga de verdade do aparelho.
  Future<void> excluir(Visita visita) async {
    await _dao.salvar(
      visita.copyWith(
        excluida: true,
        atualizadaEm: _relogio(),
        sincronizada: false,
      ),
    );
    await _aposEscrita();
  }

  Future<void> _aposEscrita() async {
    await _sync.atualizarPendentes();
    unawaited(_sync.sincronizar()); // não bloqueia a tela
  }

  static String? _limpar(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
