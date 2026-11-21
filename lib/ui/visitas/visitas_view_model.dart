import 'package:flutter/foundation.dart';

import '../../data/repositories/visita_repository.dart';
import '../../data/sync/sincronizador.dart';
import '../../domain/models/status_visita.dart';
import '../../domain/models/visita.dart';

class VisitasViewModel extends ChangeNotifier {
  VisitasViewModel(this._repo, this._sync) {
    _versaoVista = _sync.versaoDados;
    // Quando o sincronizador traz dados novos do servidor, recarrega.
    _sync.addListener(_aoMudarSync);
  }

  final VisitaRepository _repo;
  final Sincronizador _sync;
  int _versaoVista = 0;

  List<Visita> visitas = const [];
  bool carregando = true;
  String? erro;

  Future<void> carregar() async {
    try {
      visitas = await _repo.listar();
      erro = null;
    } on Exception {
      erro = 'Não foi possível ler as visitas do aparelho.';
    }
    carregando = false;
    notifyListeners();
  }

  Future<void> criar({
    required String titulo,
    required String cliente,
    required String endereco,
    required DateTime agendadaPara,
    required StatusVisita status,
    String? observacoes,
  }) async {
    await _repo.criar(
      titulo: titulo,
      cliente: cliente,
      endereco: endereco,
      agendadaPara: agendadaPara,
      status: status,
      observacoes: observacoes,
    );
    await carregar();
  }

  Future<void> atualizar(Visita v) async {
    await _repo.atualizar(v);
    await carregar();
  }

  Future<void> excluir(Visita v) async {
    // Tira da tela JÁ: o Dismissible exige que o item suma da árvore no
    // mesmo frame ("A dismissed Dismissible widget is still part of the tree").
    visitas = visitas.where((x) => x.id != v.id).toList();
    notifyListeners();
    await _repo.excluir(v);
    await carregar();
  }

  /// Puxar para atualizar: força uma rodada de sincronização.
  Future<void> sincronizarAgora() async {
    await _sync.sincronizar();
    await carregar();
  }

  void _aoMudarSync() {
    if (_sync.versaoDados != _versaoVista) {
      _versaoVista = _sync.versaoDados;
      carregar();
    } else {
      // pendentes podem ter mudado (ícone de nuvem nos itens)
      if (_sync.estado == EstadoSync.ocioso) carregar();
    }
  }

  @override
  void dispose() {
    _sync.removeListener(_aoMudarSync);
    super.dispose();
  }
}
