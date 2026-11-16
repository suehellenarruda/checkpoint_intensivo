import 'package:flutter/foundation.dart';

import '../../data/repositories/visita_repository.dart';
import '../../domain/models/status_visita.dart';
import '../../domain/models/visita.dart';

/// Estado da lista. Fala SÓ com o repositório — nunca com o sqflite.
class VisitasViewModel extends ChangeNotifier {
  VisitasViewModel(this._repo);

  final VisitaRepository _repo;

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
}
