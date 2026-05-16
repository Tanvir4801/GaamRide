const admin = require('firebase-admin');
const functions = require('firebase-functions');

admin.initializeApp();

const APPROVED_VILLAGES = [
  { name: 'Anaval', lat: 20.8306, lng: 73.2469 },
  { name: 'Kos', lat: 20.8480, lng: 73.2350 },
  { name: 'Tarkani', lat: 20.8550, lng: 73.2580 },
  { name: 'Angaldhara', lat: 20.8180, lng: 73.2280 },
  { name: 'Dholikuva', lat: 20.8650, lng: 73.2800 },
  { name: 'Lakhavadi', lat: 20.8050, lng: 73.2150 },
  { name: 'Unai', lat: 20.8550, lng: 73.2100 },
  { name: 'Doldha', lat: 20.7950, lng: 73.2600 },
  { name: 'Kamboya', lat: 20.8750, lng: 73.2200 },
];

function toRadians(degrees) {
  return (degrees * Math.PI) / 180;
}

function distanceKm(aLat, aLng, bLat, bLng) {
  const earthRadiusKm = 6371;
  const dLat = toRadians(bLat - aLat);
  const dLng = toRadians(bLng - aLng);
  const lat1 = toRadians(aLat);
  const lat2 = toRadians(bLat);

  const sinLat = Math.sin(dLat / 2);
  const sinLng = Math.sin(dLng / 2);
  const a = sinLat * sinLat + Math.cos(lat1) * Math.cos(lat2) * sinLng * sinLng;
  return 2 * earthRadiusKm * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function nearestVillage(lat, lng) {
  let nearest = '';
  let bestDistance = Number.POSITIVE_INFINITY;

  for (const village of APPROVED_VILLAGES) {
    const currentDistance = distanceKm(lat, lng, village.lat, village.lng);
    if (currentDistance < bestDistance) {
      bestDistance = currentDistance;
      nearest = village.name;
    }
  }

  return nearest;
}

async function sendTokens(tokens, message) {
  const uniqueTokens = [...new Set(tokens.filter(Boolean))];
  if (uniqueTokens.length === 0) {
    return null;
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens: uniqueTokens,
    notification: message.notification,
    data: message.data,
    android: message.android,
    apns: message.apns,
  });

  return response;
}

exports.onBookingCreated = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snap) => {
    const booking = snap.data() || {};
    const pickupLat = Number(booking.pickupLat);
    const pickupLng = Number(booking.pickupLng);

    if (!Number.isFinite(pickupLat) || !Number.isFinite(pickupLng)) {
      return null;
    }

    const fromVillage = booking.fromVillage || nearestVillage(pickupLat, pickupLng);
    const toVillage = booking.destinationVillage || booking.toVillage || 'Destination';
    const type = booking.type || 'ride';

    const liveSaathis = await admin.firestore().collection('saathis').where('isAvailable', '==', true).get();
    const tokens = [];

    liveSaathis.forEach((doc) => {
      const data = doc.data() || {};
      const position = data.position || {};
      const geopoint = position.geopoint;
      if (!geopoint || typeof geopoint.latitude !== 'number' || typeof geopoint.longitude !== 'number') {
        return;
      }

      const km = distanceKm(pickupLat, pickupLng, geopoint.latitude, geopoint.longitude);
      if (km > 20) {
        return;
      }

      if (data.fcmToken) {
        tokens.push(data.fcmToken);
      }
    });

    await sendTokens(tokens, {
      notification: {
        title: 'New Ride Request!',
        body: `${fromVillage} → ${toVillage} (${type})`,
      },
      data: {
        target: 'booking_request',
        bookingId: snap.id,
        type: String(type),
        fromVillage: String(fromVillage),
        toVillage: String(toVillage),
        distanceKm: '20',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'ride_requests',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    return null;
  });

exports.onBookingUpdated = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const previousStatus = before.status || '';
    const currentStatus = after.status || '';

    if (previousStatus === currentStatus) {
      return null;
    }

    if (currentStatus !== 'accepted' && currentStatus !== 'rejected') {
      return null;
    }

    const userId = after.userId;
    if (!userId) {
      return null;
    }

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data() || {};
    const token = userData.fcmToken;
    if (!token) {
      return null;
    }

    const saathiName = after.saathiName || 'Gaam Saathi';
    const notification = currentStatus === 'accepted'
      ? {
          title: 'Saathi is coming!',
          body: `${saathiName} accepted your ride`,
        }
      : {
          title: 'Ride not available',
          body: 'Saathi rejected. Finding another...',
        };

    await admin.messaging().send({
      token,
      notification,
      data: {
        target: 'booking_status',
        bookingId: change.after.id,
        status: currentStatus,
        saathiId: String(after.saathiId || after.assignedDriverId || ''),
        saathiName: String(saathiName),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'ride_status',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    return null;
  });