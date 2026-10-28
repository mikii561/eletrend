// Az Életrend push értesítései: amikor valami történik az adatbázisban (bump, meghívó, üzenet,
// barátjelölés, közös cél), a címzett telefonjára/böngészőjére értesítés megy, akkor is, ha az app
// be van zárva. Az esti emlékeztető és a heti összefoglaló 15 percenként ellenőrzött időzítés.
//
// A címzett eszközei: users/{uid}/push/{azonosító} (az app menti, lásd lib/push.dart).
// Telepítés: firebase deploy --only functions (Blaze csomag kell hozzá).

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
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

// Bump: csak ha a címzett nem kapcsolta ki, és nem némította a küldőt.
exports.pushBump = onDocumentCreated('bumps/{to}/items/{id}', async (event) => {
  const b = event.data && event.data.data();
  if (!b) return;
  const to = event.params.to;
  const settings = (await db.collection('bumpSettings').doc(to).get()).data() || {};
  if (settings.off === true || (settings.muted || []).includes(b.fromUid)) return;
  const title = `${b.sticker || '👋'} ${b.fromName || 'Egy barátod'} bumpolt`;
  const body = b.text || (b.eventTitle ? `📅 ${b.eventTitle}` : b.audio ? 'Hangüzenetet küldött' : b.image ? 'Képet küldött' : 'Koppints a megnyitáshoz');
  await send(to, title, body, `${APP}?n=bump:${event.params.id}`);
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

// Üzenet egy program üzenőfalán: a szervezőnek és mindenkinek, aki visszajelzett.
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

/** Budapesti dátum és idő részei. */
function budapestNow(date = new Date()) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', {
      timeZone: TIME_ZONE,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      weekday: 'short',
      hourCycle: 'h23',
    })
      .formatToParts(date)
      .map((p) => [p.type, p.value]),
  );
  return {
    day: `${parts.year}-${parts.month}-${parts.day}`,
    minutes: Number(parts.hour) * 60 + Number(parts.minute),
    sunday: parts.weekday === 'Sun',
  };
}

/** A következő nap kulcsa (ÉÉÉÉ-HH-NN). */
function nextDay(day) {
  const d = new Date(`${day}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

// Esti emlékeztető és heti összefoglaló, 15 percenként: akinek most jött el a beállított ideje.
exports.reminders = onSchedule({ schedule: '*/15 * * * *', timeZone: TIME_ZONE }, async () => {
  const now = budapestNow();
  const slot = now.minutes - (now.minutes % 15);
  const inSlot = (m) => m >= slot && m < slot + 15;

  // Csak azoknak, akiknek van push tokenje.
  const tokens = await db.collectionGroup('push').get();
  const uids = [...new Set(tokens.docs.map((d) => d.ref.parent.parent.id))];

  await Promise.all(
    uids.map(async (uid) => {
      try {
        const user = db.collection('users').doc(uid);
        const s = (await user.collection('meta').doc('settings').get()).data() || {};

        if (s.dailyReminder !== false && inSlot((s.reminderHour ?? 20) * 60 + (s.reminderMinute ?? 0))) {
          const [journal, habits] = await Promise.all([
            user.collection('journal').where('date', '>=', now.day).where('date', '<', nextDay(now.day)).limit(1).get(),
            user.collection('habits').get(),
          ]);
          const wroteJournal = !journal.empty;
          const left = habits.docs.filter((h) => !h.get('perWeek') && !(h.get('doneDays') || []).includes(now.day)).length;
          let body = null;
          if (left > 0 && !wroteJournal) body = `Még ${left} cél vár rád, és a naplódat sem írtad meg ma.`;
          else if (left > 0) body = `Még ${left} cél vár rád ma. Hajrá! 💪`;
          else if (!wroteJournal) body = 'Írd le, milyen napod volt, és miért vagy hálás! 🙏';
          if (body) await send(uid, 'Hogy telt a napod? 🌙', body);
        }

        if (now.sunday && s.weeklySummary !== false && inSlot(19 * 60)) {
          await send(uid, 'Így ment a heted 📊', 'Nézd meg, hogy haladtál a céljaiddal, és milyen volt a hangulatod.', `${APP}?n=weekly`);
        }
      } catch (e) {
        logger.warn('Emlékeztető hiba', uid, e);
      }
    }),
  );
});
