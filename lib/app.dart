import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/auth/auth_service.dart';
import 'data/sessao.dart';
import 'domain/models/usuario.dart';
import 'ui/login/login_page.dart';
import 'ui/login/login_view_model.dart';
import 'ui/visitas/visitas_page.dart';
import 'ui/visitas/visitas_view_model.dart';

class CheckpointApp extends StatelessWidget {
  const CheckpointApp({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    const semente = Color(0xFF00408A); // azul UNIT
    return MaterialApp(
      title: 'Checkpoint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: semente),
      darkTheme: ThemeData(
        colorSchemeSeed: semente,
        brightness: Brightness.dark,
      ),
      home: AuthGate(auth: auth),
    );
  }
}

/// Porteiro: decide entre login e app ouvindo o Firebase Auth.
///
/// Nenhuma tela faz `Navigator.push` para a lista depois do login:
/// a sessão mudou → o porteiro troca a árvore. Isso fecha a porta para
/// o clássico bug do "botão voltar leva de novo para a tela logada".
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<Usuario?>? _assinatura;
  bool _iniciado = false;
  Usuario? _usuario;
  Sessao? _sessao;

  @override
  void initState() {
    super.initState();
    _assinatura = widget.auth.usuario.listen(_aoMudarUsuario);
  }

  Future<void> _aoMudarUsuario(Usuario? u) async {
    if (_iniciado && u?.uid == _usuario?.uid) return;
    final antiga = _sessao;
    setState(() {
      _iniciado = true;
      _usuario = u;
      _sessao = null;
    });

    if (antiga != null) {
      // Espera a árvore antiga sair da tela antes de descartar o que ela usa.
      await WidgetsBinding.instance.endOfFrame;
      // Logout ou sessão revogada: o banco deste usuário sai do aparelho.
      await antiga.encerrar(apagarDados: true);
    }

    if (u == null) return;
    final nova = await Sessao.abrir(u);
    if (!mounted || _usuario?.uid != u.uid) {
      await nova.encerrar(apagarDados: false);
      return;
    }
    setState(() => _sessao = nova);
    // Com rede: o servidor confirma que a conta ainda vale.
    unawaited(widget.auth.revalidarSessao());
  }

  /// Encontro 01: sair = signOut. O listener acima encerra a sessão e
  /// apaga o banco. No Encontro 02 entra o aviso de "visitas não enviadas".
  Future<void> _sair() => widget.auth.sair();

  @override
  void dispose() {
    _assinatura?.cancel();
    _sessao?.encerrar(apagarDados: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_iniciado) return const _Carregando();

    final usuario = _usuario;
    if (usuario == null) {
      return ChangeNotifierProvider(
        create: (_) => LoginViewModel(widget.auth),
        child: const LoginPage(),
      );
    }

    final sessao = _sessao;
    if (sessao == null) return const _Carregando();

    return ChangeNotifierProvider(
      key: ValueKey(usuario.uid),
      create: (_) => VisitasViewModel(sessao.repositorio),
      child: VisitasPage(email: usuario.email, aoSair: _sair),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
