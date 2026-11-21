// Teste ponta a ponta contra o Firebase Emulator REAL.
//
//   firebase emulators:start --project demo-checkpoint
//   flutter test integration_test -d <simulador/emulador>
import 'package:checkpoint_intensivo/core/config/ambiente.dart';
import 'package:checkpoint_intensivo/data/auth/auth_firebase.dart';
import 'package:checkpoint_intensivo/data/local/database.dart';
import 'package:checkpoint_intensivo/data/local/visita_dao.dart';
import 'package:checkpoint_intensivo/data/remote/visita_firestore.dart';
import 'package:checkpoint_intensivo/data/repositories/visita_repository.dart';
import 'package:checkpoint_intensivo/data/sync/sincronizador.dart';
import 'package:checkpoint_intensivo/domain/models/status_visita.dart';
import 'package:checkpoint_intensivo/domain/models/visita.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore firestore;

  setUpAll(() async {
    final amb = Ambiente.atual();
    await Firebase.initializeApp(options: amb.firebaseOptions);
    auth = FirebaseAuth.instance;
    firestore = FirebaseFirestore.instance;
    firestore.settings = const Settings(persistenceEnabled: false);
    await auth.useAuthEmulator(amb.hostEmulador, 9099);
    firestore.useFirestoreEmulator(amb.hostEmulador, 8080);
  });

  testWidgets('login seguro + CRUD + sincronização com o Firestore', (
    tester,
  ) async {
    final servico = AuthFirebase(auth);
    final email = 'e2e${DateTime.now().millisecondsSinceEpoch}@unit.br';

    // ── LOGIN SEGURO ──
    await servico.cadastrar(email: email, senha: 'checkpoint2026');
    final uid = servico.atual!.uid;
    await servico.sair();
    await expectLater(
      servico.entrar(email: email, senha: 'senhaErrada1'),
      throwsA(predicate((e) => '$e'.contains('E-mail ou senha inválidos'))),
    );
    await expectLater(
      servico.entrar(email: 'naoexiste@unit.br', senha: 'qualquer123'),
      throwsA(predicate((e) => '$e'.contains('E-mail ou senha inválidos'))),
    );
    await servico.entrar(email: email, senha: 'checkpoint2026');
    expect(servico.atual!.uid, uid);

    // ── CRUD LOCAL ──
    final banco = await AppDatabase.abrir(uid);
    final dao = VisitaDao(banco.db);
    final sync = Sincronizador(
      dao: dao,
      remota: VisitaFirestore(firestore, uid),
    );
    final repo = VisitaRepository(dao, sync);

    final v = await repo.criar(
      titulo: 'Vistoria E2E',
      cliente: 'ACME',
      endereco: 'Rua A, 1',
      agendadaPara: DateTime(2026, 12, 1, 9),
    );
    await repo.atualizar(v.copyWith(status: StatusVisita.concluida));
    expect((await repo.listar()).single.status, StatusVisita.concluida);

    // ── SINCRONIZAÇÃO ──
    final r = await sync.sincronizar();
    expect(r.falhou, isFalse);
    expect(sync.pendentes, 0);

    final doc = await firestore
        .collection('users')
        .doc(uid)
        .collection('visitas')
        .doc(v.id)
        .get();
    expect(doc.data()!['status'], 'concluida');
    expect(doc.data()!['servidorEm'], isA<Timestamp>());

    // ── REGRAS: outro usuário NÃO lê a pasta deste ──
    await servico.sair();
    await servico.cadastrar(
      email: 'intruso${DateTime.now().millisecondsSinceEpoch}@unit.br',
      senha: 'checkpoint2026',
    );
    await expectLater(
      firestore.collection('users').doc(uid).collection('visitas').get(),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );

    // ── REGRAS: servidorEm forjado é recusado ──
    final meuUid = servico.atual!.uid;
    await expectLater(
      firestore
          .collection('users')
          .doc(meuUid)
          .collection('visitas')
          .doc('x')
          .set({
            ...Visita(
              id: 'x',
              titulo: 't',
              cliente: 'c',
              endereco: 'e',
              status: StatusVisita.agendada,
              agendadaPara: DateTime(2026),
              criadaEm: DateTime(2026),
              atualizadaEm: DateTime(2026),
            ).toRemoto(),
            'servidorEm': Timestamp.fromMillisecondsSinceEpoch(0),
          }),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );

    // ── EXCLUSÃO propaga como lápide ──
    await servico.sair();
    await servico.entrar(email: email, senha: 'checkpoint2026');
    await repo.excluir((await repo.listar()).single);
    await sync.sincronizar();
    expect(await dao.buscar(v.id), isNull);
    final lapide = await firestore
        .collection('users')
        .doc(uid)
        .collection('visitas')
        .doc(v.id)
        .get();
    expect(lapide.data()!['excluida'], isTrue);

    sync.dispose();
    await banco.apagar();
    await servico.sair();
  });
}
