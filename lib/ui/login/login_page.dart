import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validacao/validadores.dart';
import 'login_view_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _senhaVisivel = false;
  Timer? _relogioBloqueio;

  @override
  void dispose() {
    _relogioBloqueio?.cancel();
    _email.dispose();
    _senha.dispose(); // controller da senha some junto com a tela
    super.dispose();
  }

  Future<void> _enviar(LoginViewModel vm) async {
    if (!_form.currentState!.validate()) return;
    final ok = await vm.enviar(_email.text, _senha.text);
    if (!ok) {
      _senha.clear(); // senha errada não fica na tela
      if (vm.bloqueado) _contarBloqueio();
    }
  }

  void _contarBloqueio() {
    _relogioBloqueio?.cancel();
    _relogioBloqueio = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {});
      if (!context.read<LoginViewModel>().bloqueado) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final cadastrando = vm.modo == ModoLogin.cadastrar;
    final tema = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 64,
                        color: tema.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Checkpoint',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineMedium,
                      ),
                      Text(
                        cadastrando ? 'Criar conta' : 'Entrar',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        key: const Key('campo-email'),
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        validator: Validadores.email,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('campo-senha'),
                        controller: _senha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          helperText: cadastrando
                              ? '8+ caracteres, com letra e número'
                              : null,
                          suffixIcon: IconButton(
                            tooltip: _senhaVisivel
                                ? 'Esconder senha'
                                : 'Mostrar senha',
                            icon: Icon(
                              _senhaVisivel
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _senhaVisivel = !_senhaVisivel),
                          ),
                        ),
                        // senha: sem eco, sem sugestão, sem autocorretor
                        obscureText: !_senhaVisivel,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: [
                          cadastrando
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _enviar(vm),
                        validator: cadastrando
                            ? Validadores.senhaNova
                            : Validadores.senhaLogin,
                      ),
                      const SizedBox(height: 16),
                      if (vm.erro != null)
                        _Mensagem(texto: vm.erro!, erro: true),
                      if (vm.aviso != null)
                        _Mensagem(texto: vm.aviso!, erro: false),
                      if (vm.bloqueado)
                        _Mensagem(
                          texto:
                              'Muitas tentativas. Tente de novo em '
                              '${vm.segundosRestantes}s.',
                          erro: true,
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        key: const Key('botao-enviar'),
                        onPressed: vm.enviando || vm.bloqueado
                            ? null
                            : () => _enviar(vm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: vm.enviando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(cadastrando ? 'Criar conta' : 'Entrar'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: vm.enviando ? null : vm.alternarModo,
                        child: Text(
                          cadastrando
                              ? 'Já tenho conta'
                              : 'Não tenho conta — criar',
                        ),
                      ),
                      if (!cadastrando)
                        TextButton(
                          onPressed: vm.enviando
                              ? null
                              : () {
                                  final e = _email.text;
                                  if (Validadores.email(e) == null) {
                                    vm.esqueciSenha(e);
                                  } else {
                                    _form.currentState!.validate();
                                  }
                                },
                          child: const Text('Esqueci minha senha'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({required this.texto, required this.erro});

  final String texto;
  final bool erro;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: erro ? cs.errorContainer : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: erro ? cs.onErrorContainer : cs.onSecondaryContainer,
        ),
      ),
    );
  }
}
