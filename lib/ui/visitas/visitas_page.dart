import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/models/status_visita.dart';
import '../../domain/models/visita.dart';
import '../visita_form/visita_form_page.dart';
import 'visitas_view_model.dart';

class VisitasPage extends StatefulWidget {
  const VisitasPage({super.key, required this.email, required this.aoSair});

  final String email;

  /// Quem decide o que "sair" faz (apagar banco, signOut) é o AuthGate.
  final Future<void> Function() aoSair;

  @override
  State<VisitasPage> createState() => _VisitasPageState();
}

class _VisitasPageState extends State<VisitasPage> {
  @override
  void initState() {
    super.initState();
    context.read<VisitasViewModel>().carregar();
  }

  /// A rota nova nasce FORA desta subárvore (é filha do Navigator), então
  /// repassamos o ViewModel explicitamente com `.value`.
  Future<void> _abrirForm([Visita? visita]) {
    final vm = context.read<VisitasViewModel>();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: vm,
          child: VisitaFormPage(visita: visita),
        ),
      ),
    );
  }

  Future<bool> _confirmarExclusao(Visita v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir visita?'),
        content: Text('"${v.titulo}" será removida deste aparelho.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VisitasViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas visitas'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => widget.aoSair(),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  widget.email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const PopupMenuItem(
                value: 'sair',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sair'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _corpo(vm),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('botao-nova'),
        onPressed: () => _abrirForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova visita'),
      ),
    );
  }

  Widget _corpo(VisitasViewModel vm) {
    if (vm.carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.erro != null) {
      return Center(child: Text(vm.erro!));
    }
    return RefreshIndicator(
      onRefresh: vm.carregar,
      child: vm.visitas.isEmpty
          ? ListView(
              // ListView para o "puxar para atualizar" funcionar vazio
              children: const [
                SizedBox(height: 120),
                Icon(Icons.event_note, size: 64),
                SizedBox(height: 12),
                Center(child: Text('Nenhuma visita ainda.')),
                Center(
                  child: Text('Toque em "Nova visita" — funciona offline.'),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: vm.visitas.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final v = vm.visitas[i];
                return Dismissible(
                  key: ValueKey(v.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete),
                  ),
                  confirmDismiss: (_) => _confirmarExclusao(v),
                  onDismissed: (_) {
                    vm.excluir(v);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${v.titulo}" excluída.')),
                    );
                  },
                  child: _ItemVisita(visita: v, aoTocar: () => _abrirForm(v)),
                );
              },
            ),
    );
  }
}

class _ItemVisita extends StatelessWidget {
  const _ItemVisita({required this.visita, required this.aoTocar});

  final Visita visita;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (IconData icone, Color cor) = switch (visita.status) {
      StatusVisita.agendada => (Icons.schedule, cs.primary),
      StatusVisita.emAndamento => (Icons.directions_run, cs.tertiary),
      StatusVisita.concluida => (Icons.check_circle, Colors.green),
    };
    final data = DateFormat('dd/MM/yyyy HH:mm').format(visita.agendadaPara);

    return ListTile(
      onTap: aoTocar,
      leading: Icon(icone, color: cor),
      title: Text(visita.titulo),
      subtitle: Text('${visita.cliente} · $data\n${visita.endereco}'),
      isThreeLine: true,
      trailing: visita.sincronizada
          ? null
          : Tooltip(
              // Encontro 01: tudo fica pendente; quem envia é o Encontro 02
              message: 'Pendente de envio',
              child: Icon(Icons.cloud_upload_outlined, color: cs.outline),
            ),
    );
  }
}
