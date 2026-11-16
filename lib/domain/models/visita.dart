import 'status_visita.dart';

/// Entidade central do Checkpoint.
///
/// Três campos existem SÓ por causa do offline-first:
/// - [atualizadaEm]: relógio da última alteração, decide conflitos;
/// - [sincronizada]: `false` = está na fila para subir;
/// - [excluida]: exclusão lógica ("lápide"), para a exclusão chegar
///   ao servidor e aos outros aparelhos.
class Visita {
  const Visita({
    required this.id,
    required this.titulo,
    required this.cliente,
    required this.endereco,
    required this.status,
    required this.agendadaPara,
    this.observacoes,
    required this.criadaEm,
    required this.atualizadaEm,
    this.sincronizada = false,
    this.excluida = false,
  });

  final String id;
  final String titulo;
  final String cliente;
  final String endereco;
  final StatusVisita status;
  final DateTime agendadaPara;
  final String? observacoes;
  final DateTime criadaEm;
  final DateTime atualizadaEm;
  final bool sincronizada;
  final bool excluida;

  Visita copyWith({
    String? titulo,
    String? cliente,
    String? endereco,
    StatusVisita? status,
    DateTime? agendadaPara,
    String? Function()? observacoes,
    DateTime? atualizadaEm,
    bool? sincronizada,
    bool? excluida,
  }) {
    return Visita(
      id: id,
      titulo: titulo ?? this.titulo,
      cliente: cliente ?? this.cliente,
      endereco: endereco ?? this.endereco,
      status: status ?? this.status,
      agendadaPara: agendadaPara ?? this.agendadaPara,
      observacoes: observacoes != null ? observacoes() : this.observacoes,
      criadaEm: criadaEm,
      atualizadaEm: atualizadaEm ?? this.atualizadaEm,
      sincronizada: sincronizada ?? this.sincronizada,
      excluida: excluida ?? this.excluida,
    );
  }

  // ── SQLite (colunas snake_case, datas em epoch millis, bool em 0/1) ──

  Map<String, Object?> toMap() => {
    'id': id,
    'titulo': titulo,
    'cliente': cliente,
    'endereco': endereco,
    'status': status.valor,
    'agendada_para': agendadaPara.millisecondsSinceEpoch,
    'observacoes': observacoes,
    'criada_em': criadaEm.millisecondsSinceEpoch,
    'atualizada_em': atualizadaEm.millisecondsSinceEpoch,
    'sincronizada': sincronizada ? 1 : 0,
    'excluida': excluida ? 1 : 0,
  };

  factory Visita.fromMap(Map<String, Object?> m) => Visita(
    id: m['id']! as String,
    titulo: m['titulo']! as String,
    cliente: m['cliente']! as String,
    endereco: m['endereco']! as String,
    status: StatusVisita.deValor(m['status']! as String),
    agendadaPara: _data(m['agendada_para']),
    observacoes: m['observacoes'] as String?,
    criadaEm: _data(m['criada_em']),
    atualizadaEm: _data(m['atualizada_em']),
    sincronizada: m['sincronizada'] == 1,
    excluida: m['excluida'] == 1,
  );

  // ── Remoto (camelCase). `sincronizada` NÃO sobe: é estado local. ──

  Map<String, Object?> toRemoto() => {
    'id': id,
    'titulo': titulo,
    'cliente': cliente,
    'endereco': endereco,
    'status': status.valor,
    'agendadaPara': agendadaPara.millisecondsSinceEpoch,
    'observacoes': observacoes,
    'criadaEm': criadaEm.millisecondsSinceEpoch,
    'atualizadaEm': atualizadaEm.millisecondsSinceEpoch,
    'excluida': excluida,
  };

  /// O que vem do servidor já está, por definição, sincronizado.
  factory Visita.fromRemoto(Map<String, Object?> m) => Visita(
    id: m['id']! as String,
    titulo: m['titulo']! as String,
    cliente: m['cliente']! as String,
    endereco: m['endereco']! as String,
    status: StatusVisita.deValor(m['status']! as String),
    agendadaPara: _data(m['agendadaPara']),
    observacoes: m['observacoes'] as String?,
    criadaEm: _data(m['criadaEm']),
    atualizadaEm: _data(m['atualizadaEm']),
    sincronizada: true,
    excluida: m['excluida'] == true,
  );

  static DateTime _data(Object? millis) =>
      DateTime.fromMillisecondsSinceEpoch((millis! as num).toInt());

  @override
  String toString() =>
      'Visita($id, $titulo, ${status.valor}, sinc=$sincronizada, excl=$excluida)';
}
