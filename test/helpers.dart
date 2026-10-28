import 'package:eletrend/account.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// Bejelentkezett felhasználó egy kitalált felhővel, hogy a tesztek ne a valódi szerverhez nyúljanak.
FakeFirebaseFirestore signInFakeAccount({String uid = 'teszt', String email = 'teszt@pelda.hu'}) {
  final db = FakeFirebaseFirestore();
  Account.instance = Account(
    auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid, email: email, displayName: 'Teszt')),
    db: db,
  );
  return db;
}
