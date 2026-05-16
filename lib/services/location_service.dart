import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/village_model.dart';
import 'notification_service.dart';

typedef VillageLocation = VillageModel;

class LocationService {
  static const List<VillageLocation> approvedVillages = [
    VillageLocation(id: 'anaval', name: 'Anaval', nameGu: 'આણવલ', lat: 20.8306, lng: 73.2469, isActive: true),
    VillageLocation(id: 'kos', name: 'Kos', nameGu: 'કૉસ', lat: 20.8480, lng: 73.2350, isActive: true),
    VillageLocation(id: 'tarkani', name: 'Tarkani', nameGu: 'તારકાણી', lat: 20.8550, lng: 73.2580, isActive: true),
    VillageLocation(id: 'angaldhara', name: 'Angaldhara', nameGu: 'અંગલધરા', lat: 20.8180, lng: 73.2280, isActive: true),
    VillageLocation(id: 'dholikuva', name: 'Dholikuva', nameGu: 'ઢોળીકૂવા', lat: 20.8650, lng: 73.2800, isActive: true),
    VillageLocation(id: 'lakhavadi', name: 'Lakhavadi', nameGu: 'લખાવડી', lat: 20.8050, lng: 73.2150, isActive: true),
    VillageLocation(id: 'unai', name: 'Unai', nameGu: 'ઉનાઈ', lat: 20.8550, lng: 73.2100, isActive: true),
    VillageLocation(id: 'doldha', name: 'Doldha', nameGu: 'ડોળધા', lat: 20.7950, lng: 73.2600, isActive: true),
    VillageLocation(id: 'kamboya', name: 'Kamboya', nameGu: 'કાંબોયા', lat: 20.8750, lng: 73.2200, isActive: true),
  ];

  static const LatLng serviceSouthWest = LatLng(20.780, 73.190);
  static const LatLng serviceNorthEast = LatLng(20.920, 73.320);

  static LatLngBounds get serviceBounds => LatLngBounds(
        southwest: serviceSouthWest,
        northeast: serviceNorthEast,
      );

  static LatLng get serviceCenter => const LatLng(20.8306, 73.2469);

  static CameraPosition get initialCameraPosition =>
      CameraPosition(target: serviceCenter, zoom: 13);

  static bool isInsideServiceZone(LatLng point) {
    final inLat = point.latitude >= serviceSouthWest.latitude &&
        point.latitude <= serviceNorthEast.latitude;
    final inLng = point.longitude >= serviceSouthWest.longitude &&
        point.longitude <= serviceNorthEast.longitude;
    return inLat && inLng;
  }

  static VillageLocation? getNearestVillage(LatLng point) {
    VillageLocation? nearestVillage;
    double bestDistanceMeters = double.infinity;

    for (final village in approvedVillages) {
      final distanceMeters = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        village.lat,
        village.lng,
      );

      if (distanceMeters < bestDistanceMeters) {
        bestDistanceMeters = distanceMeters;
        nearestVillage = village;
      }
    }

    return nearestVillage;
  }

  static String? getNearestVillageName(LatLng point) {
    return getNearestVillage(point)?.name;
  }

  static String? getNearestVillageDisplayName(LatLng point) {
    return getNearestVillage(point)?.label;
  }

  static final GeoCollectionReference<Map<String, dynamic>>
      _saathisGeoCollection = GeoCollectionReference<Map<String, dynamic>>(
    FirebaseFirestore.instance.collection('saathis'),
  );

  static StreamSubscription<Position>? _driverPositionSubscription;

  static Future<bool> ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied || status.isRestricted || status.isLimited) {
      status = await Permission.locationWhenInUse.request();
    }

    return status.isGranted;
  }

  static Stream<List<DocumentSnapshot<Map<String, dynamic>>>> nearbyAvailableSaathis({
    required LatLng center,
    double radiusInKm = 5.0,
  }) {
    final centerPoint = GeoFirePoint(GeoPoint(center.latitude, center.longitude));

    return _saathisGeoCollection
        .subscribeWithin(
          center: centerPoint,
          radiusInKm: radiusInKm,
          field: 'position',
          geopointFrom: (data) {
            final position = data['position'];
            if (position is Map<String, dynamic>) {
              final geopoint = position['geopoint'];
              if (geopoint is GeoPoint) {
                return geopoint;
              }
            }
            throw StateError('Missing geopoint in saathis/{id}/position');
          },
          strictMode: true,
        )
        .map(
          (docs) => docs.where((doc) {
            final data = doc.data();
            return data != null && (data['isAvailable'] as bool? ?? false);
          }).toList(),
        );
  }

  static Future<void> upsertSaathiLiveLocation({
    required String saathiId,
    required Position position,
    required String vehicleType,
    required bool isAvailable,
  }) async {
    final geoPoint = GeoFirePoint(GeoPoint(position.latitude, position.longitude));

    await FirebaseFirestore.instance.collection('saathis').doc(saathiId).set(
      {
        'position': geoPoint.data,
        'isAvailable': isAvailable,
        'lastSeen': FieldValue.serverTimestamp(),
        'vehicleType': vehicleType,
        'fcmToken': NotificationService.currentToken,
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> startSaathiLiveLocation({
    required String saathiId,
    required String vehicleType,
  }) async {
    final hasPermission = await ensureLocationPermission();
    if (!hasPermission) {
      throw StateError('Location permission denied');
    }

    await _driverPositionSubscription?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );

    _driverPositionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        upsertSaathiLiveLocation(
          saathiId: saathiId,
          position: position,
          vehicleType: vehicleType,
          isAvailable: true,
        );
      },
    );

    final currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    await upsertSaathiLiveLocation(
      saathiId: saathiId,
      position: currentPosition,
      vehicleType: vehicleType,
      isAvailable: true,
    );
  }

  static Future<void> stopSaathiLiveLocation({
    required String saathiId,
  }) async {
    await _driverPositionSubscription?.cancel();
    _driverPositionSubscription = null;

    await FirebaseFirestore.instance.collection('saathis').doc(saathiId).set(
      {
        'isAvailable': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'fcmToken': NotificationService.currentToken,
      },
      SetOptions(merge: true),
    );
  }

  static List<NearbySaathi> mapNearbySaathis({
    required List<DocumentSnapshot<Map<String, dynamic>>> docs,
    required LatLng center,
  }) {
    final list = <NearbySaathi>[];

    for (final doc in docs) {
      final data = doc.data();
      if (data == null) {
        continue;
      }

      final position = data['position'];
      if (position is! Map<String, dynamic>) {
        continue;
      }

      final geopoint = position['geopoint'];
      if (geopoint is! GeoPoint) {
        continue;
      }

      final distanceMeters = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        geopoint.latitude,
        geopoint.longitude,
      );

      final distanceKm = distanceMeters / 1000;
      final etaMinutes = ((distanceKm / 25) * 60).round();
      final vehicleType = (data['vehicleType'] ?? data['VehicleType'] ?? data['vehicle'] ?? 'Vehicle')
          .toString()
          .trim();
      final name = (data['name'] ?? data['Name'] ?? data['saathiName'] ?? 'Saathi')
          .toString()
          .trim();
      final phone = (data['phone'] ?? data['Phone'] ?? data['mobile'] ?? '')
          .toString()
          .trim();

      list.add(
        NearbySaathi(
          id: doc.id,
          name: name,
          phone: phone,
          vehicleType: vehicleType.isEmpty ? 'Vehicle' : vehicleType,
          position: LatLng(geopoint.latitude, geopoint.longitude),
          distanceKm: distanceKm,
          etaMinutes: etaMinutes,
        ),
      );
    }

    list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return list;
  }

  static Future<void> createTestSaathisForDebug() async {
    if (!kDebugMode) return;

    try {
      final testSaathis = [
        {
          'docId': 'test_saathi_tarkani_1',
          'name': 'Raj',
          'phone': '9999000001',
          'village': 'Tarkani',
          'vehicleType': 'Auto',
          'lat': 20.8550,
          'lng': 73.2580,
        },
        {
          'docId': 'test_saathi_anaval_1',
          'name': 'Priya',
          'phone': '9999000002',
          'village': 'Anaval',
          'vehicleType': 'Bike',
          'lat': 20.8306,
          'lng': 73.2469,
        },
        {
          'docId': 'test_saathi_kos_1',
          'name': 'Amit',
          'phone': '9999000003',
          'village': 'Kos',
          'vehicleType': 'Auto',
          'lat': 20.8480,
          'lng': 73.2350,
        },
      ];

      final batch = FirebaseFirestore.instance.batch();

      for (final saathi in testSaathis) {
        final geoPoint = GeoFirePoint(
          GeoPoint(saathi['lat'] as double, saathi['lng'] as double),
        );

        final docRef = FirebaseFirestore.instance.collection('saathis').doc(saathi['docId'] as String);

        batch.set(
          docRef,
          {
            'name': saathi['name'],
            'phone': saathi['phone'],
            'village': saathi['village'],
            'vehicleType': saathi['vehicleType'],
            'position': geoPoint.data,
            'isAvailable': true,
            'rating': 5.0,
            'lastSeen': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      if (kDebugMode) {
        print('DEBUG: Created 3 test Saathis in Firebase');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Failed to create test Saathis: $e');
      }
    }
  }
}

class NearbySaathi {
  const NearbySaathi({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.position,
    required this.distanceKm,
    required this.etaMinutes,
  });

  final String id;
  final String name;
  final String phone;
  final String vehicleType;
  final LatLng position;
  final double distanceKm;
  final int etaMinutes;
}
