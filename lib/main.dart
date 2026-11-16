import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/ambiente.dart';
import 'data/auth/auth_firebase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ambiente = Ambiente.atual();
  await Firebase.initializeApp(options: ambiente.firebaseOptions);

  final auth = FirebaseAuth.instance;

  if (ambiente.usarEmulador) {
    debugPrint('[app] Firebase Emulator em ${ambiente.hostEmulador}');
    await auth.useAuthEmulator(ambiente.hostEmulador, 9099);
  }

  runApp(CheckpointApp(auth: AuthFirebase(auth)));
}
