import 'package:checkpoint_intensivo/ui/login/login_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/fakes.dart';

void main() {
  late AuthFalsa auth;
  late DateTime agora;
  late LoginViewModel vm;

  setUp(() {
    auth = AuthFalsa()..senhas['ana@unit.br'] = 'checkpoint2026';
    agora = DateTime(2026, 11, 10, 9);
    vm = LoginViewModel(auth, relogio: () => agora);
  });

  test('credencial certa entra', () async {
    expect(await vm.enviar('ana@unit.br', 'checkpoint2026'), isTrue);
    expect(auth.atual?.email, 'ana@unit.br');
    expect(vm.erro, isNull);
  });

  test('senha errada e e-mail inexistente dão A MESMA mensagem', () async {
    await vm.enviar('ana@unit.br', 'errada');
    final senhaErrada = vm.erro;
    await vm.enviar('ninguem@unit.br', 'qualquer1');
    expect(vm.erro, senhaErrada);
    expect(vm.erro, 'E-mail ou senha inválidos.');
  });

  test('5 falhas seguidas travam por 30 s sem chamar o servidor', () async {
    for (var i = 0; i < LoginViewModel.maxFalhas; i++) {
      await vm.enviar('ana@unit.br', 'errada$i');
    }
    expect(vm.bloqueado, isTrue);

    final antes = auth.chamadas;
    expect(await vm.enviar('ana@unit.br', 'checkpoint2026'), isFalse);
    expect(auth.chamadas, antes, reason: 'bloqueado não chama o servidor');

    agora = agora.add(const Duration(seconds: 31));
    expect(vm.bloqueado, isFalse);
    expect(await vm.enviar('ana@unit.br', 'checkpoint2026'), isTrue);
  });

  test('esqueci a senha responde igual, exista o e-mail ou não', () async {
    await vm.esqueciSenha('ana@unit.br');
    final a = vm.aviso;
    await vm.esqueciSenha('ninguem@unit.br');
    expect(vm.aviso, a);
  });
}
