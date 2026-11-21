import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/sync/sincronizador.dart';

/// Faixa sempre visível: quantas pendentes e quando foi a última sync.
/// (exigência do M4 em projeto/README.md)
class BarraSincronizacao extends StatelessWidget {
  const BarraSincronizacao({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<Sincronizador>();
    final cs = Theme.of(context).colorScheme;

    final (IconData icone, String texto, Color cor) = switch (sync.estado) {
      EstadoSync.sincronizando => (Icons.sync, 'Sincronizando…', cs.primary),
      EstadoSync.offline => (Icons.cloud_off, 'Offline', cs.outline),
      EstadoSync.erro => (
        Icons.sync_problem,
        'Servidor indisponível',
        cs.error,
      ),
      EstadoSync.ocioso => (
        sync.pendentes == 0 ? Icons.cloud_done : Icons.cloud_upload,
        sync.pendentes == 0 ? 'Tudo sincronizado' : 'Aguardando envio',
        sync.pendentes == 0 ? Colors.green : cs.tertiary,
      ),
    };

    final ultima = sync.ultimaSincronizacao;
    final quando = ultima == null
        ? 'nunca sincronizado'
        : 'última: ${DateFormat('dd/MM HH:mm').format(ultima)}';

    return Material(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icone, size: 18, color: cor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$texto · ${sync.pendentes} pendente(s) · $quando',
                key: const Key('texto-sync'),
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
