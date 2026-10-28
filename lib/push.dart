import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart' as impl;

/// Push értesítések a böngészőben (bezárt appra is), Firebase Cloud Messaginggel.
///
/// A token a `users/{uid}/push/{azonosító}` alá kerül; a Cloud Function (functions/index.js) innen
/// tudja, hova küldjön. iPhone-on csak a kezdőképernyőre tett app kaphat értesítést (iOS 16.4+).
class Push {
  /// A Firebase konzol → Projektbeállítások → Cloud Messaging → Web Push tanúsítványok kulcspárja
  /// (nyilvános kulcs, nem titok). Amíg üres, a push nincs bekapcsolva.
  static const vapidKey = '';

  /// Tesztekhez felülírható.
  static bool? debugSupported;

  static bool get configured => vapidKey.isNotEmpty;
  static bool get supported => debugSupported ?? (kIsWeb && impl.supported);

  /// iPhone/iPad böngészőben, még nem a kezdőképernyőről nyitva.
  static bool get needsInstall => kIsWeb && impl.ios && !impl.standalone;

  /// Fut-e már telepített appként (kezdőképernyőről).
  static bool get standalone => kIsWeb && impl.standalone;

  static bool get ios => kIsWeb && impl.ios;

  /// 'granted', 'denied', 'default' vagy 'unsupported'.
  static String get permission => kIsWeb ? impl.permission : 'unsupported';

  static bool get enabled => permission == 'granted';

  /// Engedélyt kér (ha [ask]) és elmenti a tokent. Igazat ad, ha sikerült.
  /// Az [ask] csak gombnyomásra legyen igaz (a Safari csak úgy engedi).
  static Future<bool> register(String uid, {bool ask = false, FirebaseFirestore? db}) async {
    if (!configured || !supported || (needsInstall && !ask)) return false;
    final token = await impl.token(vapidKey, ask: ask);
    if (token == null) return false;
    final id = sha1.convert(utf8.encode(token)).toString();
    await (db ?? FirebaseFirestore.instance).collection('users').doc(uid).collection('push').doc(id).set({
      'token': token,
      'platform': ios ? 'ios-web' : 'web',
      'at': FieldValue.serverTimestamp(),
    });
    return true;
  }
}
