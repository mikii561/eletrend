import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A fiók társas adatainak törlése: amit a felhasználó törölhet a szabályok szerint, az mind elmegy.
/// (A naptár-adatok, a fotók és a fiók maga az `Account.deleteAccount`-ban törlődik.)
///
/// Ami marad: a más felhasználóknál már megérkezett üzenetek (bökés, hozzászólás, jelölés), mert azok
/// a címzetteké; a név szerint szereplő hozzászólásokat a program szervezője vagy az admin törölheti.
Future<void> eraseSocialData(FirebaseFirestore db, String uid, {List<String> sharedEventIds = const []}) async {
  Future<void> step(String name, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      // Egy lépés hibája ne akadályozza a többit (pl. nincs internet vagy már törölve van).
      debugPrint('Törlés ($name) később: $e');
    }
  }

  Future<void> deleteCollection(CollectionReference<Map<String, dynamic>> col) async {
    final q = await col.get();
    for (var i = 0; i < q.docs.length; i += 400) {
      final batch = db.batch();
      for (final d in q.docs.skip(i).take(400)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  // A névjegyből kiolvassuk a barátkódot, mielőtt a névjegy törlődik.
  String? code;
  await step('kód', () async {
    code = (await db.collection('people').doc(uid).get()).data()?['code'] as String?;
  });

  // Barátságok: mindkét oldalon.
  await step('barátságok', () async {
    final mine = db.collection('friendships').doc(uid).collection('list');
    for (final d in (await mine.get()).docs) {
      await step('barátság', () => db.collection('friendships').doc(d.id).collection('list').doc(uid).delete());
    }
    await deleteCollection(mine);
  });

  await step('jelölések', () => deleteCollection(db.collection('requests').doc(uid).collection('items')));
  await step('tiltások', () => deleteCollection(db.collection('blocks').doc(uid).collection('list')));
  await step('bökések', () => deleteCollection(db.collection('nudges').doc(uid).collection('items')));
  await step('bökés-beállítások', () => db.collection('nudgeSettings').doc(uid).delete());
  await step('meghívások', () => deleteCollection(db.collection('inbox').doc(uid).collection('items')));
  await step('elérhetőség', () => db.collection('availability').doc(uid).delete());

  // Kihívások: a sajátot töröljük (a haladásokkal együtt), a többiből kilépünk.
  await step('kihívások', () async {
    final mine = await db.collection('challenges').where('members', arrayContains: uid).get();
    for (final c in mine.docs) {
      await step('kihívás', () async {
        final progress = db.collection('challenges').doc(c.id).collection('progress');
        if (c.data()['ownerUid'] == uid) {
          await deleteCollection(progress);
          await c.reference.delete();
        } else {
          await progress.doc(uid).delete();
          await c.reference.update({
            'members': FieldValue.arrayRemove([uid]),
            'names.$uid': FieldValue.delete(),
          });
        }
      });
    }
  });

  // A saját megosztott programok (a más szervezőjűek törlését a szabály úgyis megtiltja).
  for (final id in sharedEventIds) {
    await step('program', () => db.collection('events').doc(id).delete());
  }

  if (code != null) await step('barátkód', () => db.collection('codes').doc(code).delete());
  await step('névjegy', () => db.collection('people').doc(uid).delete());
  await step('adatlap', () => db.collection('profiles').doc(uid).delete());
}
