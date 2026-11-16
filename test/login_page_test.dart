import 'package:checkpoint_intensivo/ui/login/login_page.dart';
import 'package:checkpoint_intensivo/ui/login/login_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'apoio/fakes.dart';

void main() {
  late AuthFalsa auth;

  Future<void> montar(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => LoginViewModel(auth),
        child: const LoginPage(),
      ),
    ),
  );

  setUp(() => auth = AuthFalsa()..senhas['ana@unit.br'] = 'checkpoint2026');

  testWidgets('campos vazios mostram validação e não chamam o servidor', (
    tester,
  ) async {
    await montar(tester);
    await tester.tap(find.byKey(const Key('botao-enviar')));
    await tester.pump();

    expect(find.text('Informe o e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
    expect(auth.chamadas, 0);
  });

  testWidgets('senha começa escondida', (tester) async {
    await montar(tester);
    final campo = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('campo-senha')),
        matching: find.byType(TextField),
      ),
    );
    expect(campo.obscureText, isTrue);
    expect(campo.enableSuggestions, isFalse);
  });

  testWidgets('senha errada mostra erro genérico e limpa o campo', (
    tester,
  ) async {
    await montar(tester);
    await tester.enterText(find.byKey(const Key('campo-email')), 'ana@unit.br');
    await tester.enterText(find.byKey(const Key('campo-senha')), 'errada');
    await tester.tap(find.byKey(const Key('botao-enviar')));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
    final senha = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('campo-senha')),
        matching: find.byType(TextField),
      ),
    );
    expect(senha.controller!.text, isEmpty);
  });

  testWidgets('cadastro aplica a política de senha', (tester) async {
    await montar(tester);
    await tester.tap(find.text('Não tenho conta — criar'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('campo-email')), 'bia@unit.br');
    await tester.enterText(find.byKey(const Key('campo-senha')), 'abc');
    await tester.tap(find.byKey(const Key('botao-enviar')));
    await tester.pump();

    expect(find.text('Mínimo de 8 caracteres.'), findsOneWidget);
    expect(auth.chamadas, 0);
  });
}
