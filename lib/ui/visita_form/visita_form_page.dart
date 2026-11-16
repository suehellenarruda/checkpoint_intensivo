import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/validacao/validadores.dart';
import '../../domain/models/status_visita.dart';
import '../../domain/models/visita.dart';
import '../visitas/visitas_view_model.dart';

/// Formulário único para CRIAR (visita == null) e EDITAR.
class VisitaFormPage extends StatefulWidget {
  const VisitaFormPage({super.key, this.visita});

  final Visita? visita;

  @override
  State<VisitaFormPage> createState() => _VisitaFormPageState();
}

class _VisitaFormPageState extends State<VisitaFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _cliente;
  late final TextEditingController _endereco;
  late final TextEditingController _observacoes;
  late StatusVisita _status;
  late DateTime _agendadaPara;
  bool _salvando = false;

  bool get _editando => widget.visita != null;

  @override
  void initState() {
    super.initState();
    final v = widget.visita;
    _titulo = TextEditingController(text: v?.titulo);
    _cliente = TextEditingController(text: v?.cliente);
    _endereco = TextEditingController(text: v?.endereco);
    _observacoes = TextEditingController(text: v?.observacoes);
    _status = v?.status ?? StatusVisita.agendada;
    _agendadaPara =
        v?.agendadaPara ??
        DateTime.now()
            .add(const Duration(days: 1))
            .copyWith(
              hour: 9,
              minute: 0,
              second: 0,
              millisecond: 0,
              microsecond: 0,
            );
  }

  @override
  void dispose() {
    _titulo.dispose();
    _cliente.dispose();
    _endereco.dispose();
    _observacoes.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _agendadaPara,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_agendadaPara),
    );
    if (hora == null) return;
    setState(() {
      _agendadaPara = DateTime(
        data.year,
        data.month,
        data.day,
        hora.hour,
        hora.minute,
      );
    });
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    final vm = context.read<VisitasViewModel>();
    final obs = _observacoes.text;
    if (_editando) {
      await vm.atualizar(
        widget.visita!.copyWith(
          titulo: _titulo.text,
          cliente: _cliente.text,
          endereco: _endereco.text,
          status: _status,
          agendadaPara: _agendadaPara,
          observacoes: () => obs,
        ),
      );
    } else {
      await vm.criar(
        titulo: _titulo.text,
        cliente: _cliente.text,
        endereco: _endereco.text,
        agendadaPara: _agendadaPara,
        status: _status,
        observacoes: obs,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Visita salva no aparelho.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar visita' : 'Nova visita')),
      body: Form(
        key: _form,
        // SingleChildScrollView + Column, NÃO ListView: o ListView desmonta
        // campos fora da tela, e campo desmontado escapa do validate().
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('campo-titulo'),
                controller: _titulo,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                maxLength: 120,
                textInputAction: TextInputAction.next,
                validator: (v) => Validadores.obrigatorio(v),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('campo-cliente'),
                controller: _cliente,
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                  border: OutlineInputBorder(),
                ),
                maxLength: 120,
                textInputAction: TextInputAction.next,
                validator: (v) => Validadores.obrigatorio(v),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('campo-endereco'),
                controller: _endereco,
                decoration: const InputDecoration(
                  labelText: 'Endereço',
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
                textInputAction: TextInputAction.next,
                validator: (v) => Validadores.obrigatorio(v, max: 200),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<StatusVisita>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final s in StatusVisita.values)
                    DropdownMenuItem(value: s, child: Text(s.rotulo)),
                ],
                onChanged: (s) => setState(() => _status = s ?? _status),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: const Icon(Icons.event),
                title: const Text('Agendada para'),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(_agendadaPara),
                ),
                onTap: _escolherData,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacoes,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('botao-salvar'),
                onPressed: _salvando ? null : _salvar,
                icon: const Icon(Icons.save),
                label: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
