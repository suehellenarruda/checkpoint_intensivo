enum StatusVisita {
  agendada('agendada', 'Agendada'),
  emAndamento('em_andamento', 'Em andamento'),
  concluida('concluida', 'Concluída');

  const StatusVisita(this.valor, this.rotulo);

  /// Como é gravado no SQLite e no Firestore.
  final String valor;

  /// Como aparece na tela.
  final String rotulo;

  static StatusVisita deValor(String valor) => StatusVisita.values.firstWhere(
    (s) => s.valor == valor,
    orElse: () => StatusVisita.agendada,
  );
}
