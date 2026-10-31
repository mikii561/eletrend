// A LIFEUP push értesítései: amikor valami történik az adatbázisban (bökés, meghívó, hozzászólás,
// barátjelölés, közös cél), a címzett telefonjára/böngészőjére értesítés megy, akkor is, ha az app
// be van zárva. (Az emlékeztetőket a telefon maga ütemezi, azokhoz nem kell szerver.)
//
// A címzett eszközei: users/{uid}/push/{azonosító} (az app menti, lásd lib/push.dart).
// Telepítés: firebase deploy --only functions (Blaze csomag kell hozzá).

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions, logger } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// A Firestore adatbázis helyéhez illő régió (eur3 → europe-west1, nam5 → us-central1).
const REGION = 'europe-west1';
setGlobalOptions({ region: REGION, maxInstances: 5 });

const APP = 'https://mikii561.github.io/eletrend/';
const ICON = APP + 'icons/Icon-192.png';
const TIME_ZONE = 'Europe/Budapest';

/** Rövidítés, hogy az értesítés ne legyen túl hosszú. */
function cut(text, max = 120) {
  const s = String(text || '').trim();
  return s.length > max ? s.slice(0, max - 1) + '…' : s;
}

/** Értesítés egy felhasználó összes eszközére; az érvénytelenné vált tokeneket töröljük. */
async function send(uid, title, body, link = APP) {
  const snap = await db.collection('users').doc(uid).collection('push').get();
  if (snap.empty) return;
  const tokens = snap.docs.map((d) => d.get('token')).filter(Boolean);
  if (tokens.length === 0) return;
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    webpush: {
      notification: { title: cut(title, 80), body: cut(body), icon: ICON },
      fcmOptions: { link },
    },
  });
  const dead = ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'];
  await Promise.all(
    res.responses.map((r, i) => (!r.success && r.error && dead.includes(r.error.code) ? snap.docs[i].ref.delete() : null)),
  );
}

/** Ugyanaz több címzettnek (a küldőt kihagyva). */
async function sendAll(uids, skip, title, body, link) {
  const targets = [...new Set(uids)].filter((u) => u && u !== skip);
  await Promise.all(targets.map((u) => send(u, title, body, link).catch((e) => logger.warn('Push hiba', u, e))));
}

// Bökés: csak ha a címzett nem kapcsolta ki, és nem némította a küldőt.
exports.pushNudge = onDocumentCreated('nudges/{to}/items/{id}', async (event) => {
  const n = event.data && event.data.data();
  if (!n) return;
  const to = event.params.to;
  const settings = (await db.collection('nudgeSettings').doc(to).get()).data() || {};
  if (settings.off === true || (settings.muted || []).includes(n.fromUid)) return;
  const title = `${n.emoji || '👋'} ${n.fromName || 'Egy barátod'}`;
  const body = n.eventTitle ? `${n.text} · ${n.eventTitle}` : n.text;
  await send(to, title, body, `${APP}?n=nudge:${event.params.id}`);
});

// Meghívás egy programra.
exports.pushInvite = onDocumentCreated('inbox/{uid}/items/{eventId}', async (event) => {
  const d = event.data && event.data.data();
  if (!d) return;
  let when = '';
  if (d.date) {
    when = new Intl.DateTimeFormat('hu-HU', {
      timeZone: TIME_ZONE,
      month: 'long',
      day: 'numeric',
      weekday: 'long',
      hour: '2-digit',
      minute: '2-digit',
    }).format(new Date(d.date));
  }
  await send(event.params.uid, `${d.fromName || 'Egy barátod'} meghívott: ${d.title || 'program'}`, when, `${APP}?e=${event.params.eventId}`);
});

// Barátjelölés.
exports.pushFriendRequest = onDocumentCreated('requests/{to}/items/{from}', async (event) => {
  const d = event.data && event.data.data();
  if (!d) return;
  await send(event.params.to, `${d.fromName || 'Valaki'} barátnak jelölt`, 'Nyisd meg a Barátok fület az elfogadáshoz.');
});

// Hozzászólás egy közös programhoz: a szervezőnek és mindenkinek, aki visszajelzett.
exports.pushChat = onDocumentCreated('events/{eventId}/messages/{mid}', async (event) => {
  const m = event.data && event.data.data();
  if (!m) return;
  const ref = db.collection('events').doc(event.params.eventId);
  const [ev, rsvps] = await Promise.all([ref.get(), ref.collection('rsvps').get()]);
  if (!ev.exists) return;
  const uids = [ev.get('ownerUid'), ...rsvps.docs.map((d) => d.id)];
  await sendAll(uids, m.uid, `${m.name || 'Valaki'} · ${ev.get('title') || 'program'}`, m.text, `${APP}?e=${event.params.eventId}`);
});

// Közös cél vagy kihívás indítása: a meghívott barátoknak.
exports.pushChallenge = onDocumentCreated('challenges/{cid}', async (event) => {
  const c = event.data && event.data.data();
  if (!c) return;
  const owner = (c.names || {})[c.ownerUid] || 'Egy barátod';
  const title = c.kind === 'goal' ? `${owner} közös célt indított veled` : `${owner} kihívott: ${c.emoji || '🏁'}`;
  await sendAll(c.members || [], c.ownerUid, title, c.title);
});

