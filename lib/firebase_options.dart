// A Firebase-projekt (lifest-c95f3) beállításai. Ezek nem titkosak: a weboldalon
// is látszanak; az adatokat a firestore.rules szabályai védik.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => kIsWeb ? web : android;

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDl_vaVNBglOVGTRE_lsDHug96BsAkc_ss',
    appId: '1:738529451537:web:407a509ffc04f5c2129bb0',
    messagingSenderId: '738529451537',
    projectId: 'lifest-c95f3',
    authDomain: 'lifest-c95f3.firebaseapp.com',
    storageBucket: 'lifest-c95f3.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDl_vaVNBglOVGTRE_lsDHug96BsAkc_ss',
    appId: '1:738529451537:android:653b9517aad28207129bb0',
    messagingSenderId: '738529451537',
    projectId: 'lifest-c95f3',
    storageBucket: 'lifest-c95f3.firebasestorage.app',
  );
}
