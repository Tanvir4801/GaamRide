import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:math' as math;

import '../models/village_model.dart';

typedef Village = VillageModel;

class VillageService {
  static const String collectionPath = 'villages';

  // Approved villages with coordinates (approxima updated per user)
  static const List<Village> approvedVillages = [
    Village(
      id: 'anaval',
      name: 'Anaval',
      nameGu: 'આણવલ',
      lat: 22.9200,
      lng: 73.0100,
      isActive: true,
      taluka: 'Ankleshwar',
    ),
    Village(
      id: 'kos',
      name: 'Kos',
      nameGu: 'કોસ',
      lat: 22.9400,
      lng: 73.0300,
      isActive: true,
      taluka: 'Ankleshwar',
    ),
    Village(
      id: 'doldha',
      name: 'Doldha',
      nameGu: 'ડોલધા',
      lat: 22.9100,
      lng: 73.0500,
      isActive: true,
      taluka: 'Ankleshwar',
    ),
    Village(
      id: 'kamboya',
      name: 'Kamboya',
      nameGu: 'કમ્બોયા',
      lat: 22.9600,
      lng: 72.9800,
      isActive: true,
      taluka: 'Ankleshwar',
    ),
    Village(
      id: 'tarkani',
      name: 'Tarkani',
      nameGu: 'તરકાણી',
      lat: 22.8900,
      lng: 73.0200,
      isActive: true,
      taluka: 'Ankleshwar',
    ),
    Village(
      id: 'dholikuva',
      name: 'Dholikuva',
      nameGu: 'ધોલીકુવા',
      lat: 22.9300,
      lng: 72.9900,
      isActive: true,
      taluka: 'Ankleshwar',
    ),
    Village(
      id: 'angaldhara',
      name: 'Angaldhara',
      nameGu: 'અંગાલધારા',
      lat: 22.9500,
      lng: 73.0400,
      isActive: true,
      taluka: 'Ankleshwar',
    ),
    Village(
      id: 'lakhavadi',
      name: 'Lakhavadi',
      nameGu: 'લખાવડી',
      lat: 22.9700,
      lng: 73.0600,
      isActive: true,
      taluka: 'Ankleshwar',
    ),
    Village(
      id: 'unai',
      name: 'Unai',
      nameGu: 'ઉણાઈ',
      lat: 22.8800,
      lng: 72.9700,
      isActive: true,
      taluka: 'Ankleshwar',
    ),
  ];

  // One-time initialization: write approved villages to Firestore with isActive=true
  static Future<void> initializeVillages() async {
    if (!kDebugMode) {
      return; // Only in debug mode
    }

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (final village in approvedVillages) {
        final docRef = db.collection(collectionPath).doc(village.id);
        batch.set(docRef, village.toFirestore(), SetOptions(merge: true));
      }

      await batch.commit();
      if (kDebugMode) {
        print('✓ Villages initialized in Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Failed to initialize villages: $e');
      }
    }
  }

  // Fetch all active villages from Firestore
  // In production, villages are filtered by isActive=true in Firestore
  // In debug, we skip the network call and use the hardcoded list above
  static Future<List<Village>> fetchActiveVillages() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionPath)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => VillageModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Failed to fetch villages: $e');
      }
      // Fallback to hardcoded list in debug
      return approvedVillages;
    }
  }

  // Find village by coordinates (for setting pickup location)
  static Village? findNearestVillage(double lat, double lng) {
    const earthRadiusKm = 6371;

    double haversineDistance(double lat1, double lng1, double lat2, double lng2) {
      final dLat = (lat2 - lat1) * math.pi / 180;
      final dLng = (lng2 - lng1) * math.pi / 180;
      final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
          (math.cos(lat1 * math.pi / 180) *
              math.cos(lat2 * math.pi / 180) *
              math.sin(dLng / 2) *
              math.sin(dLng / 2));
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return earthRadiusKm * c;
    }

    Village? nearest;
    double minDistance = double.infinity;

    for (final village in approvedVillages) {
      final distance = haversineDistance(lat, lng, village.lat, village.lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = village;
      }
    }

    return minDistance < 2.0 ? nearest : null; // Within 2km
  }
}
