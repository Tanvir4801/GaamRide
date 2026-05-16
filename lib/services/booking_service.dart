import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/booking_models.dart';

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

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  static CollectionReference<Map<String, dynamic>> get _driverRequests =>
      _firestore.collection('driver_requests');

  static Stream<DocumentSnapshot<Map<String, dynamic>>> bookingStream(
    String bookingId,
  ) {
    return _bookings.doc(bookingId).snapshots();
  }

  static Future<BookingCreateResult> createBookingAndDispatch({
    required CreateBookingInput input,
  }) async {
    final bookingRef = _bookings.doc();

    await bookingRef.set({
      'type': input.type,
      'userId': input.userId,
      'pickupLat': input.pickupLat,
      'pickupLng': input.pickupLng,
      'destinationVillage': input.destinationVillage,
      'vehicleType': input.vehicleType,
      'durationLabel': input.durationLabel,
      'loadDescription': input.loadDescription,
      'status': BookingStatus.pending,
      'assignedDriverId': null,
      'driverId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final driverIds = await _nearbyDriverIds(
      type: input.type,
      center: LatLng(input.pickupLat, input.pickupLng),
      radiusKm: input.radiusKm ?? (input.type == BookingType.haul ? 10 : 5),
      vehicleType: input.vehicleType,
    );

    if (driverIds.isEmpty) {
      await bookingRef.update({
        'status': BookingStatus.cancelled,
        'updatedAt': FieldValue.serverTimestamp(),
        'cancelReason': 'no_drivers',
      });
      throw NoDriversFoundException();
    }

    final batch = _firestore.batch();
    for (final driverId in driverIds) {
      final reqRef = _driverRequests.doc();
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
    );
  }

  static Future<void> autoCancelIfStillSearching(String bookingId) async {
    final ref = _bookings.doc(bookingId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (!snap.exists || data == null) return;

      final status = data['status']?.toString();
      if (status == BookingStatus.pending || status == BookingStatus.searching) {
        tx.update(ref, {
          'status': BookingStatus.cancelled,
          'updatedAt': FieldValue.serverTimestamp(),
          'cancelReason': 'timeout',
        });
      }
    });
  }

  static Future<void> rejectDriverRequest(String requestId) async {
    await _driverRequests.doc(requestId).set(
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
  }) async {
    final requestRef = _driverRequests.doc(requestId);

    late final String bookingId;

    await _firestore.runTransaction((tx) async {
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
      if (bookingId.isEmpty) {
        throw BookingException('Invalid booking id in request');
      }

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
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(requestRef, {
        'status': DriverRequestStatus.accepted,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    final others = await _driverRequests
        .where('bookingId', isEqualTo: bookingId)
        .where('status', isEqualTo: DriverRequestStatus.pending)
        .get();

    if (others.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in others.docs) {
      if (doc.id == requestId) continue;
      batch.update(doc.reference, {
        'status': DriverRequestStatus.rejected,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static Future<void> respondToBookingRequest({
    required String bookingId,
    required bool accept,
    required String saathiId,
    String? saathiName,
  }) async {
    final bookingRef = _bookings.doc(bookingId);

    await _firestore.runTransaction((tx) async {
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
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<List<String>> _nearbyDriverIds({
    required String type,
    required LatLng center,
    required double radiusKm,
    String? vehicleType,
  }) async {
    final String collectionName;
    if (type == BookingType.ride) {
      collectionName = 'saathis';
    } else {
      collectionName = 'haul_vehicles';
    }

    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(
      _firestore.collection(collectionName),
    );

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
            throw StateError('Missing geopoint in $collectionName/{id}/position');
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

      if (type == BookingType.haul && vehicleType != null && vehicleType.isNotEmpty) {
        final docVehicleType = (data['vehicleType'] ?? '').toString();
        if (docVehicleType != vehicleType) continue;
      }

      String resolvedDriverId = doc.id;
      if (type == BookingType.ride) {
        final phone = (data['phone'] ?? '').toString().trim();
        if (phone.isNotEmpty) {
          final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
          if (phone.startsWith('+')) {
            resolvedDriverId = phone;
          } else if (digits.length == 10) {
            resolvedDriverId = '+91$digits';
          } else if (digits.length > 10) {
            resolvedDriverId = '+${digits.substring(digits.length - 12)}';
          } else {
            resolvedDriverId = phone;
          }
        }
      } else {
        final ownerId = (data['ownerId'] ?? '').toString().trim();
        if (ownerId.isNotEmpty) {
          resolvedDriverId = ownerId;
        }
      }

      ids.add(resolvedDriverId);
    }

    return ids.toList();
  }
}
