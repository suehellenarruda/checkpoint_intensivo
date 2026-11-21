import 'package:cloud_firestore/cloud_firestore.dart';
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
  final firestore = FirebaseFirestore.instance;

  // O cache offline do app é o NOSSO SQLite. Desligamos o cache do
  // Firestore para existir uma única fonte da verdade no aparelho.
  firestore.settings = const Settings(persistenceEnabled: false);

  if (ambiente.usarEmulador) {
    debugPrint('[app] Firebase Emulator em ${ambiente.hostEmulador}');
    await auth.useAuthEmulator(ambiente.hostEmulador, 9099);
    firestore.useFirestoreEmulator(ambiente.hostEmulador, 8080);
  }

  runApp(CheckpointApp(auth: AuthFirebase(auth), firestore: firestore));
}
