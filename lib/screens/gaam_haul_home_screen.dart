import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import 'booking_search_screen.dart';
import 'vehicle_owner_dashboard.dart';
import 'vehicle_register_screen.dart';

class GaamHaulHomeScreen extends StatefulWidget {
  const GaamHaulHomeScreen({super.key});

  @override
  State<GaamHaulHomeScreen> createState() => _GaamHaulHomeScreenState();
}

class _GaamHaulHomeScreenState extends State<GaamHaulHomeScreen> {
  static const Color _orange = Color(0xFFE65100);

  final TextEditingController _loadDescriptionController =
      TextEditingController();

  LatLng? _currentLocation;
  VillageLocation? _nearestVillage;
  bool _isGettingLocation = true;

  bool _isCheckingOwner = true;
  bool _hasVehicleRegistered = false;
  String? _ownerDocId;
  bool _showFarmerView = false;

  String? _selectedVehicleType;
  String? _selectedDuration;
  bool _searched = false;
  bool _isSearching = false;

  static const Map<String, String> _vehicleTypeLabels = {
    'mini_tempo': '🚛 મિની ટેમ્પો',
    'pickup': '🚜 પિકઅપ ટ્રક',
    'tractor': '🚜 ટ્રેક્ટર',
  };

  static const Map<String, String> _durationLabels = {
    '1_hour': '1 કલાક',
    '2_hours': '2 કલાક',
    'half_day': 'અર્ધો દિવસ',
    'full_day': 'આખો દિવસ',
  };

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _checkOwnerRegistration();
  }

  @override
  void dispose() {
    _loadDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _currentLocation = currentLocation;
        _nearestVillage = LocationService.getNearestVillage(currentLocation);
        _isGettingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _checkOwnerRegistration({bool forceOwnerView = false}) async {
    setState(() {
      _isCheckingOwner = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _hasVehicleRegistered = false;
          _ownerDocId = null;
          _isCheckingOwner = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('haul_vehicles')
          .doc(user.uid)
          .get();

      if (!mounted) return;
      setState(() {
        _hasVehicleRegistered = doc.exists;
        _ownerDocId = doc.exists ? user.uid : null;
        if (doc.exists && forceOwnerView) {
          _showFarmerView = false;
        }
        _isCheckingOwner = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasVehicleRegistered = false;
        _ownerDocId = null;
        _isCheckingOwner = false;
      });
    }
  }

  String _locationLabel() {
    if (_isGettingLocation) {
      return 'Detecting... / શોધી રહ્યા છીએ...';
    }

    final nearestVillage = _nearestVillage;
    if (nearestVillage != null) {
      return '${nearestVillage.nameGu} (${nearestVillage.name})';
    }

    final currentLocation = _currentLocation;
    if (currentLocation == null) {
      return 'Current location unavailable / સ્થાન ઉપલબ્ધ નથી';
    }

    return '${currentLocation.latitude.toStringAsFixed(5)}, ${currentLocation.longitude.toStringAsFixed(5)}';
  }

  Future<void> _searchVehicles() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS સ્થાન હજુ મળ્યું નથી / GPS location not detected yet'),
        ),
      );
      return;
    }

    if (_selectedVehicleType == null || _selectedDuration == null) {
      return;
    }

    setState(() {
      _isSearching = true;
      _searched = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ??
          'guest_${DateTime.now().millisecondsSinceEpoch}';

      final result = await BookingService.createBookingAndDispatch(
        input: CreateBookingInput(
          type: BookingType.haul,
          userId: userId,
          pickupLat: _currentLocation!.latitude,
          pickupLng: _currentLocation!.longitude,
          destinationVillage: _nearestVillage?.name ?? 'Anaval',
          vehicleType: _selectedVehicleType,
          durationLabel: _durationLabels[_selectedDuration],
          loadDescription: _loadDescriptionController.text.trim(),
          radiusKm: 10,
        ),
      );

      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingSearchScreen(
            bookingId: result.bookingId,
            type: BookingType.haul,
            primaryColor: _orange,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _searched = false;
      });
    } on NoDriversFoundException {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searched = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('અત્યારે આ વિસ્તારમાં કોઈ વાહન ઉપલબ્ધ નથી'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searched = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('વાહન શોધવામાં નિષ્ફળ / Failed to search vehicles'),
        ),
      );
    }
  }

  Future<void> _openRegisterScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const VehicleRegisterScreen()),
    );

    if (result == true) {
      await _checkOwnerRegistration(forceOwnerView: true);
    }
  }

  Future<void> _addTestVehicles() async {
    if (!kDebugMode) return;

    try {
      final testVehicles = [
        {
          'docId': 'test_haul_vehicle_1',
          'ownerId': 'test_owner_1',
          'ownerName': 'Ramesh Patel',
          'phone': '9876543210',
          'vehicleType': 'mini_tempo',
          'capacity': '500kg',
          'ratePerHour': 600,
          'isAvailable': true,
          'position': GeoFirePoint(const GeoPoint(20.8480, 73.2350)),
          'villageName': 'Kos',
        },
        {
          'docId': 'test_haul_vehicle_2',
          'ownerId': 'test_owner_2',
          'ownerName': 'Suresh Desai',
          'phone': '9876543211',
          'vehicleType': 'pickup',
          'capacity': '1000kg',
          'ratePerHour': 800,
          'isAvailable': true,
          'position': GeoFirePoint(const GeoPoint(20.8550, 73.2580)),
          'villageName': 'Tarkani',
        },
        {
          'docId': 'test_haul_vehicle_3',
          'ownerId': 'test_owner_3',
          'ownerName': 'Bharat Chaudhary',
          'phone': '9876543212',
          'vehicleType': 'tractor',
          'capacity': '2000kg',
          'ratePerHour': 500,
          'isAvailable': true,
          'position': GeoFirePoint(const GeoPoint(20.8180, 73.2280)),
          'villageName': 'Angaldhara',
        },
      ];

      final batch = FirebaseFirestore.instance.batch();
      for (final vehicle in testVehicles) {
        final ref = FirebaseFirestore.instance
            .collection('haul_vehicles')
            .doc(vehicle['docId']! as String);

        batch.set(ref, {
          'ownerId': vehicle['ownerId'],
          'ownerName': vehicle['ownerName'],
          'phone': vehicle['phone'],
          'vehicleType': vehicle['vehicleType'],
          'capacity': vehicle['capacity'],
          'ratePerHour': vehicle['ratePerHour'],
          'isAvailable': vehicle['isAvailable'],
          'position': (vehicle['position']! as GeoFirePoint).data,
          'villageName': vehicle['villageName'],
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test vehicles added in Firestore'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add test vehicles'),
        ),
      );
    }
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.defaultPadding),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_pin, color: _orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'તમારું સ્થાન / Your Location',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _locationLabel(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'વાહન પ્રકાર / Vehicle Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: _vehicleTypeLabels.entries.map((entry) {
            final isSelected = _selectedVehicleType == entry.key;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedVehicleType = entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _orange.withValues(alpha: 0.10)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _orange : Colors.black26,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? _orange : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'કેટલા સમય માટે? / Duration',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _durationLabels.entries.map((entry) {
            final isSelected = _selectedDuration == entry.key;
            return ChoiceChip(
              selected: isSelected,
              label: Text(entry.value),
              selectedColor: _orange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => setState(() => _selectedDuration = entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFarmerBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLocationCard(),
          const SizedBox(height: 12),
          _buildVehicleTypeSelector(),
          const SizedBox(height: 12),
          _buildDurationSelector(),
          const SizedBox(height: 12),
          TextField(
            controller: _loadDescriptionController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText:
                  'શું લઈ જવાનું છે? (વૈકલ્પિક) / What to carry? (optional)\nશાકભાજી, ખાતર, સામાન...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: (_selectedVehicleType != null && _selectedDuration != null)
                ? _searchVehicles
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('વાહન શોધો / Find Vehicle'),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _addTestVehicles,
              child: const Text('Add Test Vehicles'),
            ),
          ],
          const SizedBox(height: 16),
          if (_isSearching)
            const Center(child: CircularProgressIndicator())
          else if (_searched)
            const Column(
              children: [
                Text(
                  'વાહન મળ્યું નથી, ફરી પ્રયત્ન કરો',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'No vehicle available in your area right now',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            )
          else
            const Text(
              'વાહન પસંદ કરીને શોધો / Choose options and find vehicle',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          const SizedBox(height: 18),
          if (!_hasVehicleRegistered)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Flexible(
                  child: Text(
                    'શું તમારી પાસે ટેમ્પો/ટ્રક છે? નોંધો →',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: _openRegisterScreen,
                  child: const Text('વાહન નોંધો / Register'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingOwner) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          title: const Text('GaamHaul'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasVehicleRegistered && !_showFarmerView && _ownerDocId != null) {
      return VehicleOwnerDashboard(
        vehicleDocId: _ownerDocId!,
        onSwitchToSearch: () {
          setState(() {
            _showFarmerView = true;
          });
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: const Text('GaamHaul'),
        actions: [
          if (_hasVehicleRegistered)
            TextButton(
              onPressed: () {
                setState(() {
                  _showFarmerView = false;
                });
              },
              child: const Text(
                'ડેશબોર્ડ / Dashboard',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _buildFarmerBody(),
    );
  }
}
