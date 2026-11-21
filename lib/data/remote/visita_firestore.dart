import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/visita.dart';
import 'visita_remota.dart';

/// Implementação de [VisitaRemota] sobre o Cloud Firestore.
///
/// Caminho: `users/{uid}/visitas/{id}`. Quem garante que um usuário não
/// lê a pasta do outro é o `firestore.rules`, não este código.
class VisitaFirestore implements VisitaRemota {
  VisitaFirestore(
    this._firestore,
    this._uid, {
    this.timeout = const Duration(seconds: 10),
  });

  final FirebaseFirestore _firestore;
  final String _uid;
  final Duration timeout;

  CollectionReference<Map<String, dynamic>> get _colecao =>
      _firestore.collection('users').doc(_uid).collection('visitas');

  @override
  Future<void> enviar(Visita visita) async {
    final dados = <String, Object?>{
      ...visita.toRemoto(),
      // carimbo preenchido PELO SERVIDOR; as regras exigem isso
      'servidorEm': FieldValue.serverTimestamp(),
    };
    await _comTimeout(_colecao.doc(visita.id).set(dados));
  }

  @override
  Future<List<VisitaRecebida>> alteradasDesde(int desde) async {
    final consulta = _colecao
        .where(
          'servidorEm',
          isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(desde),
        )
        .orderBy('servidorEm');
    final snap = await _comTimeout(
      consulta.get(const GetOptions(source: Source.server)),
    );
    return snap.docs.map((d) {
      final dados = d.data();
      final carimbo = dados['servidorEm'] as Timestamp;
      return VisitaRecebida(
        Visita.fromRemoto(dados),
        carimbo.millisecondsSinceEpoch,
      );
    }).toList();
  }

  /// Sem rede, o Firestore deixa o `Future` pendurado esperando a conexão.
  /// O timeout transforma "pendurado" em "falhou", e a visita fica na fila.
  Future<T> _comTimeout<T>(Future<T> f) async {
    try {
      return await f.timeout(timeout);
    } on TimeoutException {
      throw const FalhaRemota('tempo esgotado (sem conexão?)');
    } on FirebaseException catch (e) {
      throw FalhaRemota(e.code);
    }
  }
}
