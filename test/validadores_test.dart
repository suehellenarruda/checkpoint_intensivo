import 'package:checkpoint_intensivo/core/validacao/validadores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('aceita e-mail comum', () {
      expect(Validadores.email('ana@unit.br'), isNull);
    });
    test('recusa vazio e sem arroba', () {
      expect(Validadores.email(''), 'Informe o e-mail.');
      expect(Validadores.email('ana.unit.br'), 'E-mail inválido.');
    });
  });

  group('senhaNova (política do cadastro)', () {
    test('curta demais', () {
      expect(Validadores.senhaNova('a1'), 'Mínimo de 8 caracteres.');
    });
    test('sem número', () {
      expect(Validadores.senhaNova('abcdefgh'), 'Use pelo menos um número.');
    });
    test('sem letra', () {
      expect(Validadores.senhaNova('12345678'), 'Use pelo menos uma letra.');
    });
    test('válida', () {
      expect(Validadores.senhaNova('checkpoint2026'), isNull);
    });
  });

  test('login não aplica política, só exige preenchimento', () {
    expect(Validadores.senhaLogin(''), 'Informe a senha.');
    expect(Validadores.senhaLogin('x'), isNull);
  });
}
