/// Validadores de formulário. Funções puras: fáceis de testar.
///
/// Validar no app melhora a experiência; quem GARANTE a regra é o servidor
/// (Firebase Auth para senha, `firestore.rules` para os dados).
abstract final class Validadores {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Informe o e-mail.';
    if (v.length > 254 || !_email.hasMatch(v)) return 'E-mail inválido.';
    return null;
  }

  /// No LOGIN só exigimos que a senha exista: a política vale no cadastro.
  static String? senhaLogin(String? valor) {
    if (valor == null || valor.isEmpty) return 'Informe a senha.';
    return null;
  }

  /// Política de senha do CADASTRO: 8+ caracteres, com letra e número.
  static String? senhaNova(String? valor) {
    final v = valor ?? '';
    if (v.length < 8) return 'Mínimo de 8 caracteres.';
    if (v.length > 128) return 'Máximo de 128 caracteres.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v)) return 'Use pelo menos uma letra.';
    if (!RegExp(r'\d').hasMatch(v)) return 'Use pelo menos um número.';
    return null;
  }

  static String? obrigatorio(String? valor, {int max = 120}) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Campo obrigatório.';
    if (v.length > max) return 'Máximo de $max caracteres.';
    return null;
  }
}
