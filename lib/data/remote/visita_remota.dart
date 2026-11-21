import '../../domain/models/visita.dart';

/// O que o sincronizador precisa do servidor. Duas operações, só.
abstract interface class VisitaRemota {
  /// Cria ou substitui a visita no servidor (idempotente pelo `id`).
  Future<void> enviar(Visita visita);

  /// Visitas alteradas no servidor DEPOIS do carimbo [desde]
  /// (relógio do servidor, epoch millis). `0` = todas.
  Future<List<VisitaRecebida>> alteradasDesde(int desde);
}

/// Visita vinda do servidor + o carimbo de tempo do SERVIDOR.
///
/// Usamos o relógio do servidor para saber "o que mudou desde a última
/// vez" porque o relógio do celular pode estar errado.
class VisitaRecebida {
  const VisitaRecebida(this.visita, this.servidorEm);

  final Visita visita;
  final int servidorEm;
}

/// Erro de rede/servidor. O sincronizador trata, a UI só mostra o estado.
class FalhaRemota implements Exception {
  const FalhaRemota(this.motivo);

  final String motivo;

  @override
  String toString() => 'FalhaRemota($motivo)';
}
