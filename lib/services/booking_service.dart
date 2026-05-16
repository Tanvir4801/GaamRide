import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/booking_models.dart';
import '../utils/constants.dart';
import '../utils/fare_calculator.dart';
import '../utils/otp_generator.dart';

class BookingException implements Exception {
  BookingException(this.message);
  final String message;

  @override
  String toString() => message;
}

class NoDriversFoundException extends BookingException {
  NoDriversFoundException()
      : super('No nearby drivers available for this booking.');
}

class AlreadyAcceptedException extends BookingException {
  AlreadyAcceptedException() : super('This booking is already accepted.');
}

class BookingService {
  BookingService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection(AppConstants.bookingsCollection);

  static CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection(AppConstants.driverRequestsCollection);

  static CollectionReference<Map<String, dynamic>> get _saathis =>
      _db.collection(AppConstants.saathiCollection);

  // ─── Stream helpers ──────────────────────────────────────────────────────────

  static Stream<DocumentSnapshot<Map<String, dynamic>>> bookingStream(
    String bookingId,
  ) =>
      _bookings.doc(bookingId).snapshots();

  // ─── Create + dispatch ───────────────────────────────────────────────────────

  /// Creates a booking and dispatches driver requests in parallel.
  /// Parallel update: booking doc creation + nearby driver fetch run concurrently.
  static Future<BookingCreateResult> createBookingAndDispatch({
    required CreateBookingInput input,
  }) async {
    final bookingRef = _bookings.doc();
    final otp = (input.type == BookingType.ride) ? OtpGenerator.generate() : null;

    double? fare;
    if (input.type == BookingType.ride) {
      fare = FareCalculator.calculateRideFare(5.0);
    }

    // Create booking doc (non-blocking — we start driver search in parallel below)
    final bookingFuture = bookingRef.set({
      'type': input.type,
      'userId': input.userId,
      'customerId': input.userId,
      'customerName': input.customerName ?? '',
      'customerPhone': input.customerPhone ?? '',
      'pickupLat': input.pickupLat,
      'pickupLng': input.pickupLng,
      'destinationVillage': input.destinationVillage,
      'vehicleType': input.vehicleType ?? '',
      'durationLabel': input.durationLabel ?? '',
      'loadDescription': input.loadDescription ?? '',
      'status': BookingStatus.pending,
      'assignedDriverId': null,
      'driverId': null,
      'saathiId': null,
      'saathiName': null,
      'saathiPhone': null,
      'saathiLat': null,
      'saathiLng': null,
      if (otp != null) 'otp': otp,
      if (fare != null) 'fare': fare,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Parallel: fetch nearby drivers at the same time as booking creation
    final driversFuture = _nearbyDriverIds(
      type: input.type,
      center: LatLng(input.pickupLat, input.pickupLng),
      radiusKm: input.radiusKm ?? (input.type == BookingType.haul ? 10 : 5),
      vehicleType: input.vehicleType,
    );

    // Wait for both in parallel
    final results = await Future.wait([bookingFuture, driversFuture]);
    final driverIds = results[1] as List<String>;

    if (driverIds.isEmpty) {
      // Cancel booking in background, no need to await
      bookingRef.update({
        'status': BookingStatus.cancelled,
        'updatedAt': FieldValue.serverTimestamp(),
        'cancelReason': 'no_drivers',
      });
      throw NoDriversFoundException();
    }

    // Create all driver_requests in a single batch (parallel write)
    final batch = _db.batch();
    for (final driverId in driverIds) {
      final reqRef = _requests.doc();
      batch.set(reqRef, {
        'bookingId': bookingRef.id,
        'driverId': driverId,
        'status': DriverRequestStatus.pending,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    return BookingCreateResult(
      bookingId: bookingRef.id,
      notifiedDriverCount: driverIds.length,
      otp: otp,
      fare: fare,
    );
  }

  // ─── Saathi location: PARALLEL UPDATE ────────────────────────────────────────

  /// Updates both the active ride doc AND the saathis collection simultaneously.
  /// This is the core "parallel update" feature — both writes fire at the same time.
  static Future<void> updateSaathiLocationParallel({
    required String bookingId,
    required String saathiId,
    required double lat,
    required double lng,
  }) async {
    final geoPoint = GeoFirePoint(GeoPoint(lat, lng));

    // Fire both Firestore updates in parallel — neither waits for the other
    await Future.wait([
      // 1. Update the active ride doc with real-time saathi location
      _bookings.doc(bookingId).update({
        'saathiLat': lat,
        'saathiLng': lng,
        'saathiLastUpdate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      // 2. Update saathis collection for proximity discovery
      _saathis.doc(saathiId).set({
        'position': geoPoint.data,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    ]);
  }

  /// Update ride status with optional saathi info (parallel with saathi doc update)
  static Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
    Map<String, dynamic>? extraFields,
  }) async {
    await _bookings.doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      ...?extraFields,
    });
  }

  // ─── OTP verification ────────────────────────────────────────────────────────

  static Future<bool> verifyOtpAndStartRide({
    required String bookingId,
    required String enteredOtp,
  }) async {
    final snap = await _bookings.doc(bookingId).get();
    final data = snap.data();
    if (data == null) return false;

    final storedOtp = data['otp']?.toString() ?? '';
    if (!OtpGenerator.verify(enteredOtp, storedOtp)) return false;

    await _bookings.doc(bookingId).update({
      'status': BookingStatus.started,
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  // ─── Ride lifecycle ──────────────────────────────────────────────────────────

  static Future<void> markSaathiArriving(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': BookingStatus.arriving,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> completeRide({
    required String bookingId,
    required String saathiId,
  }) async {
    // Parallel: mark booking complete AND mark saathi available again
    await Future.wait([
      _bookings.doc(bookingId).update({
        'status': BookingStatus.completed,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      _saathis.doc(saathiId).set({
        'isAvailable': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    ]);
  }

  static Future<void> submitRating({
    required String bookingId,
    required String saathiId,
    required int stars,
  }) async {
    await _bookings.doc(bookingId).update({
      'customerRating': stars,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Cancel ─────────────────────────────────────────────────────────────────

  static Future<void> autoCancelIfStillSearching(String bookingId) async {
    final ref = _bookings.doc(bookingId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (!snap.exists || data == null) return;

      final status = data['status']?.toString();
      if (status == BookingStatus.pending ||
          status == BookingStatus.searching) {
        tx.update(ref, {
          'status': BookingStatus.cancelled,
          'updatedAt': FieldValue.serverTimestamp(),
          'cancelReason': 'timeout',
        });
      }
    });
  }

  static Future<void> cancelBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': BookingStatus.cancelled,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'cancelReason': 'user_cancelled',
    });
  }

  // ─── Driver request accept / reject ─────────────────────────────────────────

  static Future<void> rejectDriverRequest(String requestId) async {
    await _requests.doc(requestId).set(
      {
        'status': DriverRequestStatus.rejected,
        'timestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> acceptDriverRequest({
    required String requestId,
    required String driverId,
    String? saathiName,
    String? saathiPhone,
  }) async {
    final requestRef = _requests.doc(requestId);
    late final String bookingId;

    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(requestRef);
      final reqData = reqSnap.data();
      if (!reqSnap.exists || reqData == null) {
        throw BookingException('Request not found');
      }

      if ((reqData['status'] ?? DriverRequestStatus.pending) !=
          DriverRequestStatus.pending) {
        throw BookingException('Request is not pending');
      }

      bookingId = (reqData['bookingId'] ?? '').toString();
      if (bookingId.isEmpty) throw BookingException('Invalid booking id');

      final bookingRef = _bookings.doc(bookingId);
      final bookingSnap = await tx.get(bookingRef);
      final bookingData = bookingSnap.data();
      if (!bookingSnap.exists || bookingData == null) {
        throw BookingException('Booking not found');
      }

      final bookingStatus = bookingData['status']?.toString();
      if (bookingStatus != BookingStatus.pending &&
          bookingStatus != BookingStatus.searching) {
        throw AlreadyAcceptedException();
      }

      tx.update(bookingRef, {
        'status': BookingStatus.accepted,
        'driverId': driverId,
        'assignedDriverId': driverId,
        'saathiId': driverId,
        'saathiName': saathiName,
        'saathiPhone': saathiPhone ?? '',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(requestRef, {
        'status': DriverRequestStatus.accepted,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    // Reject all other pending requests for this booking (parallel batch)
    final others = await _requests
        .where('bookingId', isEqualTo: bookingId)
        .where('status', isEqualTo: DriverRequestStatus.pending)
        .get();

    if (others.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in others.docs) {
        if (doc.id == requestId) continue;
        batch.update(doc.reference, {
          'status': DriverRequestStatus.rejected,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  static Future<void> respondToBookingRequest({
    required String bookingId,
    required bool accept,
    required String saathiId,
    String? saathiName,
    String? saathiPhone,
  }) async {
    final bookingRef = _bookings.doc(bookingId);

    await _db.runTransaction((tx) async {
      final bookingSnap = await tx.get(bookingRef);
      final bookingData = bookingSnap.data();
      if (!bookingSnap.exists || bookingData == null) {
        throw BookingException('Booking not found');
      }

      final bookingStatus = bookingData['status']?.toString();
      if (bookingStatus != BookingStatus.pending &&
          bookingStatus != BookingStatus.searching) {
        throw AlreadyAcceptedException();
      }

      tx.update(bookingRef, {
        'status': accept ? BookingStatus.accepted : BookingStatus.rejected,
        'driverId': accept ? saathiId : bookingData['driverId'],
        'assignedDriverId': accept ? saathiId : bookingData['assignedDriverId'],
        'saathiId': accept ? saathiId : bookingData['saathiId'],
        'saathiName': accept ? saathiName : bookingData['saathiName'],
        'saathiPhone': accept ? (saathiPhone ?? '') : bookingData['saathiPhone'],
        if (accept) 'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ─── Nearby driver discovery ─────────────────────────────────────────────────

  static Future<List<String>> _nearbyDriverIds({
    required String type,
    required LatLng center,
    required double radiusKm,
    String? vehicleType,
  }) async {
    final collectionName = type == BookingType.ride
        ? AppConstants.saathiCollection
        : AppConstants.haulVehicleCollection;

    final geoCollection =
        GeoCollectionReference<Map<String, dynamic>>(_db.collection(collectionName));

    final docs = await geoCollection
        .subscribeWithin(
          center: GeoFirePoint(GeoPoint(center.latitude, center.longitude)),
          radiusInKm: radiusKm,
          field: 'position',
          geopointFrom: (data) {
            final position = data['position'];
            if (position is Map<String, dynamic>) {
              final geo = position['geopoint'];
              if (geo is GeoPoint) return geo;
            }
            throw StateError('Missing geopoint in $collectionName');
          },
          strictMode: true,
        )
        .first;

    final ids = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      if (data == null) continue;

      final isAvailable = data['isAvailable'] as bool? ?? false;
      if (!isAvailable) continue;

      if (type == BookingType.haul &&
          vehicleType != null &&
          vehicleType.isNotEmpty) {
        final docVehicleType = (data['vehicleType'] ?? '').toString();
        if (docVehicleType != vehicleType) continue;
      }

      String resolvedId = doc.id;
      if (type == BookingType.ride) {
        final phone = (data['phone'] ?? '').toString().trim();
        if (phone.isNotEmpty) {
          final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
          if (phone.startsWith('+')) {
            resolvedId = phone;
          } else if (digits.length == 10) {
            resolvedId = '+91$digits';
          } else if (digits.length > 10) {
            resolvedId = '+${digits.substring(digits.length - 12)}';
          } else {
            resolvedId = phone;
          }
        }
      } else {
        final ownerId = (data['ownerId'] ?? '').toString().trim();
        if (ownerId.isNotEmpty) resolvedId = ownerId;
      }

      ids.add(resolvedId);
    }

    return ids.toList();
  }
}
