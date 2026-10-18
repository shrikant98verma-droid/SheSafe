// SheSafe Cloud Functions.
//
// 1. When she presses SOS (a new document in `sos`), push the alert to her
//    trusted contacts and to nearby SheSafe users.
// 2. When a nearby woman taps "I can help", let her read the live location.

const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const MAX_NEARBY = 100; // never alert more than this many people at once
const LOCATION_MAX_AGE_MS = 48 * 60 * 60 * 1000; // ignore locations older than 48 hours

function distanceM(aLat, aLng, bLat, bLng) {
  const R = 6371000;
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(bLat - aLat);
  const dLng = rad(bLng - aLng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(aLat)) * Math.cos(rad(bLat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// Nearby users only get a rough distance, never her position.
function roughDistance(m) {
  const rounded = Math.max(100, Math.round(m / 100) * 100);
  return rounded >= 1000
    ? `About ${(rounded / 1000).toFixed(1)} km away`
    : `About ${rounded} m away`;
}

async function sendAll(messages) {
  for (let i = 0; i < messages.length; i += 500) {
    await admin.messaging().sendEach(messages.slice(i, i + 500));
  }
}

// Data-only, high-priority messages so the phone's background handler runs
// even when the app is closed.
function message(token, data) {
  return {
    token,
    data,
    android: { priority: 'high', ttl: 120 * 1000 },
  };
}

exports.onSosCreated = onDocumentCreated('sos/{sosId}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const sos = snap.data();
  const sosId = event.params.sosId;

  // ---- 1. trusted contacts (matched by phone number) ----
  const contactUids = new Set();
  const contactMessages = [];
  const phones = sos.contactPhones || [];
  for (let i = 0; i < phones.length; i += 30) {
    const users = await db
      .collection('users')
      .where('phone', 'in', phones.slice(i, i + 30))
      .get();
    users.forEach((u) => {
      contactUids.add(u.id);
      const token = u.get('fcmToken');
      if (token) {
        contactMessages.push(
          message(token, {
            type: 'sos',
            sosId,
            name: String(sos.ownerName || 'Someone'),
            phone: String(sos.ownerPhone || ''),
            lat: sos.lat != null ? String(sos.lat) : '',
            lng: sos.lng != null ? String(sos.lng) : '',
          })
        );
      }
    });
  }
  await sendAll(contactMessages);

  // ---- 2. nearby SheSafe users ----
  const nearbyUids = [];
  if (sos.alertNearby && sos.lat != null && sos.lng != null) {
    const radius = Math.min(Math.max(Number(sos.radiusM) || 1000, 200), 3000);
    const dLat = radius / 111320;
    const users = await db
      .collection('users')
      .where('receiveNearbyAlerts', '==', true)
      .where('lat', '>=', sos.lat - dLat)
      .where('lat', '<=', sos.lat + dLat)
      .get();

    const nearbyMessages = [];
    users.forEach((u) => {
      if (nearbyUids.length >= MAX_NEARBY) return;
      if (u.id === sos.ownerUid || contactUids.has(u.id)) return;
      const lat = u.get('lat');
      const lng = u.get('lng');
      const token = u.get('fcmToken');
      const updated = u.get('updatedAt');
      if (lat == null || lng == null || !token) return;
      if (!updated || Date.now() - updated.toMillis() > LOCATION_MAX_AGE_MS) return;
      const d = distanceM(sos.lat, sos.lng, lat, lng);
      if (d > radius) return;
      nearbyUids.push(u.id);
      nearbyMessages.push(
        message(token, { type: 'nearby', sosId, distance: roughDistance(d) })
      );
    });
    await sendAll(nearbyMessages);
  }

  // Remember who was alerted (needed by the security rules) and the count
  // (shown on her screen).
  await snap.ref.update({ nearbyUids, nearbyCount: nearbyUids.length });
});

// A nearby woman who tapped "I can help" may now read the live location.
exports.onResponseWritten = onDocumentWritten(
  'sos/{sosId}/responses/{uid}',
  async (event) => {
    const after = event.data && event.data.after && event.data.after.data();
    if (!after || after.role !== 'nearby') return;
    await db
      .doc(`sos/${event.params.sosId}`)
      .update({ helperUids: admin.firestore.FieldValue.arrayUnion(event.params.uid) });
  }
);
