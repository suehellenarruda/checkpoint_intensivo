/// O mínimo que o app precisa saber de quem está logado.
/// A UI nunca vê o `User` do Firebase: troca de provedor não quebra telas.
class Usuario {
  const Usuario({required this.uid, required this.email});

  final String uid;
  final String email;
}
