import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/visita.dart';
import '../local/visita_dao.dart';
import '../remote/visita_remota.dart';

enum EstadoSync { ocioso, sincronizando, offline, erro }

/// Resultado de uma rodada, útil para testes e para o log.
class ResultadoSync {
  const ResultadoSync({
    this.enviadas = 0,
    this.recebidas = 0,
    this.conflitos = 0,
    this.falhou = false,
  });

  final int enviadas;
  final int recebidas;
  final int conflitos;
  final bool falhou;

  @override
  String toString() =>
      'ResultadoSync(enviadas: $enviadas, recebidas: $recebidas, '
      'conflitos: $conflitos, falhou: $falhou)';
}

/// O coração do offline-first.
///
/// Regra de ouro: a fonte da verdade é o SQLite. A tela lê e escreve SÓ
/// no banco local; este objeto, em segundo plano, conversa com o servidor:
///
/// ```
/// 1. PUXAR      o que mudou no servidor desde o último carimbo
/// 2. CONFLITO   chegou do servidor uma visita que AQUI está pendente?
///               vence quem tem o atualizadaEm mais recente
/// 3. EMPURRAR   cada visita com sincronizada = 0 → servidor
/// ```
class Sincronizador extends ChangeNotifier {
  Sincronizador({
    required this.dao,
    required this.remota,
    Stream<bool>? conectividade,
    DateTime Function()? relogio,
  }) : _relogio = relogio ?? DateTime.now {
    // Voltou a rede? Sincroniza sozinho.
    _assinatura = conectividade?.listen((online) {
      _online = online;
      if (online) {
        unawaited(sincronizar());
      } else {
        _mudarEstado(EstadoSync.offline);
      }
    });
  }

  static const chaveUltimoPull = 'ultimo_pull_servidor';
  static const chaveUltimaSync = 'ultima_sync';

  final VisitaDao dao;
  final VisitaRemota remota;
  final DateTime Function() _relogio;
  StreamSubscription<bool>? _assinatura;

  bool _online = true;
  bool _pedirDeNovo = false;
  bool _descartado = false;

  EstadoSync estado = EstadoSync.ocioso;
  int pendentes = 0;
  DateTime? ultimaSincronizacao;

  /// Aumenta a cada rodada que trouxe dados novos. A lista observa isso
  /// para recarregar do banco.
  int versaoDados = 0;

  /// Carrega contadores do banco (chamar uma vez ao abrir a sessão).
  Future<void> iniciar() async {
    final ms = await dao.lerMeta(chaveUltimaSync);
    if (ms != null) {
      ultimaSincronizacao = DateTime.fromMillisecondsSinceEpoch(int.parse(ms));
    }
    await atualizarPendentes();
  }

  Future<void> atualizarPendentes() async {
    pendentes = await dao.contarPendentes();
    _notificar();
  }

  /// Rodada em andamento; `null` quando parado.
  Future<ResultadoSync>? _emAndamento;

  /// Informa o estado da rede conhecido na abertura da sessão.
  void informarConectividade(bool online) {
    _online = online;
    if (!online) _mudarEstado(EstadoSync.offline);
  }

  /// Roda uma sincronização completa. Seguro chamar várias vezes:
  /// se já há uma rodando, pede mais UMA rodada ao final e devolve o
  /// MESMO Future — quem espera, espera até a fila esvaziar de verdade.
  Future<ResultadoSync> sincronizar() {
    final atual = _emAndamento;
    if (atual != null) {
      _pedirDeNovo = true;
      return atual;
    }
    if (!_online) {
      _mudarEstado(EstadoSync.offline);
      return Future.value(const ResultadoSync(falhou: true));
    }
    return _emAndamento = _executar();
  }

  Future<ResultadoSync> _executar() async {
    try {
      ResultadoSync resultado;
      do {
        _pedirDeNovo = false;
        resultado = await _rodada();
      } while (_pedirDeNovo && !resultado.falhou && !_descartado);
      return resultado;
    } finally {
      // finally: mesmo que algo inesperado estoure, a fila não trava.
      _emAndamento = null;
    }
  }

  Future<ResultadoSync> _rodada() async {
    _mudarEstado(EstadoSync.sincronizando);
    var enviadas = 0, recebidas = 0, conflitos = 0;
    try {
      // ── 1. PUXAR ─────────────────────────────────────────────────
      // Puxamos ANTES de empurrar: assim enxergamos o que outra pessoa
      // mudou no servidor antes de sobrescrever às cegas.
      final desde = int.parse(await dao.lerMeta(chaveUltimoPull) ?? '0');
      var maiorCarimbo = desde;
      for (final r in await remota.alteradasDesde(desde)) {
        final daNuvem = r.visita;
        final local = await dao.buscar(daNuvem.id);

        if (local != null && !local.sincronizada) {
          // ── 2. CONFLITO: last-write-wins por atualizadaEm ─────────
          conflitos++;
          final nuvemVence = daNuvem.atualizadaEm.isAfter(local.atualizadaEm);
          debugPrint(
            '[sync] conflito ${daNuvem.id}: '
            '${nuvemVence ? 'servidor' : 'aparelho'} vence',
          );
          if (nuvemVence) await _aplicar(daNuvem);
          // senão: a local continua pendente e sobe logo abaixo
        } else {
          await _aplicar(daNuvem);
        }
        recebidas++;
        if (r.servidorEm > maiorCarimbo) maiorCarimbo = r.servidorEm;
      }
      await dao.gravarMeta(chaveUltimoPull, '$maiorCarimbo');

      // ── 3. EMPURRAR ──────────────────────────────────────────────
      for (final v in await dao.pendentes()) {
        await remota.enviar(v);
        final marcou = await dao.marcarSincronizada(v);
        // Lápide já confirmada no servidor: pode sumir do aparelho.
        if (marcou && v.excluida) await dao.apagarDeVez(v.id);
        enviadas++;
      }

      final agora = _relogio();
      await dao.gravarMeta(chaveUltimaSync, '${agora.millisecondsSinceEpoch}');
      ultimaSincronizacao = agora;
      if (recebidas > 0) versaoDados++;
      pendentes = await dao.contarPendentes();
      _mudarEstado(EstadoSync.ocioso);
      return ResultadoSync(
        enviadas: enviadas,
        recebidas: recebidas,
        conflitos: conflitos,
      );
    } on FalhaRemota catch (e) {
      // Nada se perde: o que não subiu continua com sincronizada = 0.
      debugPrint('[sync] falhou: ${e.motivo}');
      pendentes = await dao.contarPendentes();
      _mudarEstado(EstadoSync.erro);
      return ResultadoSync(
        enviadas: enviadas,
        recebidas: recebidas,
        conflitos: conflitos,
        falhou: true,
      );
    } on Exception catch (e) {
      // Ex.: banco fechado porque o usuário saiu no meio da rodada.
      debugPrint('[sync] interrompido: ${e.runtimeType}');
      if (!_descartado) _mudarEstado(EstadoSync.erro);
      return const ResultadoSync(falhou: true);
    }
  }

  Future<void> _aplicar(Visita remota) async {
    if (remota.excluida) {
      await dao.apagarDeVez(remota.id);
    } else {
      await dao.salvar(remota);
    }
  }

  void _mudarEstado(EstadoSync novo) {
    estado = novo;
    _notificar();
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _assinatura?.cancel();
    super.dispose();
  }
}
