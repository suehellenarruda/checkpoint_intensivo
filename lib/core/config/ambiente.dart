import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';

/// Configuração do app lida em tempo de COMPILAÇÃO via `--dart-define`.
///
/// Nada de chave dentro do código-fonte:
///
/// ```bash
/// # modo aula (padrão): Firebase Emulator na sua máquina, sem conta Google
/// flutter run
///
/// # projeto Firebase real: chaves num arquivo fora do Git
/// flutter run --dart-define-from-file=config/firebase_projeto.json
/// ```
class Ambiente {
  const Ambiente._({
    required this.usarEmulador,
    required this.hostEmulador,
    required this.firebaseOptions,
  });

  final bool usarEmulador;
  final String hostEmulador;
  final FirebaseOptions firebaseOptions;

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _forcarEmulador = bool.fromEnvironment('USE_EMULATOR');
  static const _hostEmulador = String.fromEnvironment('EMULATOR_HOST');

  factory Ambiente.atual() {
    final semProjeto = _apiKey.isEmpty || _projectId.isEmpty;
    final usarEmulador = semProjeto || _forcarEmulador;

    // Emulador do Android enxerga o computador em 10.0.2.2;
    // simulador do iOS, em localhost. Celular físico: passe o IP da máquina
    // com --dart-define=EMULATOR_HOST=192.168.0.10
    final host = _hostEmulador.isNotEmpty
        ? _hostEmulador
        : (Platform.isAndroid ? '10.0.2.2' : 'localhost');

    final options = semProjeto
        ? _opcoesDemo()
        : const FirebaseOptions(
            apiKey: _apiKey,
            appId: _appId,
            messagingSenderId: _senderId,
            projectId: _projectId,
          );

    return Ambiente._(
      usarEmulador: usarEmulador,
      hostEmulador: host,
      firebaseOptions: options,
    );
  }

  /// Projeto `demo-*`: o Firebase Emulator aceita sem conta e sem internet.
  static FirebaseOptions _opcoesDemo() => FirebaseOptions(
    // Falsa, mas no FORMATO de uma chave real: o SDK do iOS recusa
    // (e derruba o app) se não tiver 39 caracteres começando com "A".
    apiKey: 'AIzaDemo0000000000000000000000000000000',
    appId: Platform.isIOS
        ? '1:000000000000:ios:0000000000000000'
        : '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-checkpoint',
  );
}
