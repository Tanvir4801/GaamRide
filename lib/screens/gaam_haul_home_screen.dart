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
import '../utils/fare_calculator.dart';
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
  static const Color _orangeSurface = Color(0xFFFBE9E7);

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
  bool _isSearching = false;

  static const Map<String, Map<String, String>> _vehicleTypeInfo = {
    'mini_tempo': {'label': 'મિની ટેમ્પો', 'sublabel': 'Mini Tempo', 'icon': '🚚'},
    'pickup': {'label': 'પિકઅપ ટ્રક', 'sublabel': 'Pickup Truck', 'icon': '🛻'},
    'tractor': {'label': 'ટ્રેક્ટર', 'sublabel': 'Tractor', 'icon': '🚜'},
    'truck_407': {'label': '407 ટ્રક', 'sublabel': '407 Truck', 'icon': '🚛'},
  };

  static const Map<String, Map<String, String>> _durationInfo = {
    '1_hour': {'label': '1 કલાક', 'sublabel': '1 hour'},
    '2_hours': {'label': '2 કલાક', 'sublabel': '2 hours'},
    'half_day': {'label': 'અર્ધો દિવસ', 'sublabel': 'Half day (4h)'},
    'full_day': {'label': 'આખો દિવસ', 'sublabel': 'Full day (8h)'},
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
    setState(() => _isGettingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _isGettingLocation = false);
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _isGettingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final loc = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _currentLocation = loc;
        _nearestVillage = LocationService.getNearestVillage(loc);
        _isGettingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _checkOwnerRegistration({bool forceOwnerView = false}) async {
    setState(() => _isCheckingOwner = true);
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
        if (doc.exists && forceOwnerView) _showFarmerView = false;
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
    if (_isGettingLocation) return 'Detecting... / શોધી રહ્યા છીએ...';
    if (_nearestVillage != null) {
      return '${_nearestVillage!.nameGu} (${_nearestVillage!.name})';
    }
    if (_currentLocation != null) {
      return '${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}';
    }
    return 'Location unavailable / સ્થાન ઉપલબ્ધ નથી';
  }

  double? _fareEstimate() {
    if (_selectedVehicleType == null || _selectedDuration == null) return null;
    return FareCalculator.calculateHaulOwnerFare(600, _selectedDuration!);
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
    if (_selectedVehicleType == null || _selectedDuration == null) return;

    setState(() => _isSearching = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ??
          'guest_${DateTime.now().millisecondsSinceEpoch}';

      final durationLabelMap = {
        '1_hour': '1 કલાક',
        '2_hours': '2 કલાક',
        'half_day': 'અર્ધો દિવસ',
        'full_day': 'આખો દિવસ',
      };

      final result = await BookingService.createBookingAndDispatch(
        input: CreateBookingInput(
          type: BookingType.haul,
          userId: userId,
          pickupLat: _currentLocation!.latitude,
          pickupLng: _currentLocation!.longitude,
          destinationVillage: _nearestVillage?.name ?? 'Anaval',
          vehicleType: _selectedVehicleType,
          durationLabel: durationLabelMap[_selectedDuration],
          loadDescription: _loadDescriptionController.text.trim(),
          radiusKm: 10,
        ),
      );

      if (!mounted) return;
      setState(() => _isSearching = false);

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingSearchScreen(
            bookingId: result.bookingId,
            type: BookingType.haul,
            primaryColor: _orange,
            pickupLocation: _currentLocation,
            destinationVillage: _nearestVillage?.name,
          ),
        ),
      );
    } on NoDriversFoundException {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('આ વિસ્તારમાં કોઈ વાહન ઉપલબ્ધ નથી / No vehicles available nearby'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('વાહન શોધવામાં ભૂલ / Failed to search vehicles'),
        ),
      );
    }
  }

  Future<void> _openRegisterScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const VehicleRegisterScreen()),
    );
    if (result == true) await _checkOwnerRegistration(forceOwnerView: true);
  }

  Future<void> _addTestVehicles() async {
    if (!kDebugMode) return;
    try {
      final testVehicles = [
        {'docId': 'test_haul_v1', 'ownerId': 'test_owner_1', 'ownerName': 'Ramesh Patel', 'phone': '9876543210', 'vehicleType': 'mini_tempo', 'capacity': '500kg', 'ratePerHour': 600, 'isAvailable': true, 'lat': 20.8480, 'lng': 73.2350, 'villageName': 'Kos'},
        {'docId': 'test_haul_v2', 'ownerId': 'test_owner_2', 'ownerName': 'Suresh Desai',  'phone': '9876543211', 'vehicleType': 'pickup',    'capacity': '1000kg','ratePerHour': 800, 'isAvailable': true, 'lat': 20.8550, 'lng': 73.2580, 'villageName': 'Tarkani'},
        {'docId': 'test_haul_v3', 'ownerId': 'test_owner_3', 'ownerName': 'Bharat Chaudhary','phone': '9876543212', 'vehicleType': 'tractor',   'capacity': '2000kg','ratePerHour': 500, 'isAvailable': true, 'lat': 20.8180, 'lng': 73.2280, 'villageName': 'Angaldhara'},
      ];

      final batch = FirebaseFirestore.instance.batch();
      for (final v in testVehicles) {
        final geoPoint = GeoFirePoint(GeoPoint(v['lat'] as double, v['lng'] as double));
        final ref = FirebaseFirestore.instance
            .collection('haul_vehicles')
            .doc(v['docId'] as String);
        batch.set(ref, {
          'ownerId': v['ownerId'], 'ownerName': v['ownerName'], 'phone': v['phone'],
          'vehicleType': v['vehicleType'], 'capacity': v['capacity'],
          'ratePerHour': v['ratePerHour'], 'isAvailable': v['isAvailable'],
          'position': geoPoint.data, 'villageName': v['villageName'],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test vehicles added!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add test vehicles')),
      );
    }
  }

  Widget _buildVehicleTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'વાહન પ્રકાર / Vehicle Type',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: _vehicleTypeInfo.entries.map((entry) {
            final isSelected = _selectedVehicleType == entry.key;
            final info = entry.value;
            return GestureDetector(
              onTap: () => setState(() => _selectedVehicleType = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _orangeSurface : Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  border: Border.all(
                    color: isSelected ? _orange : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(info['icon']!, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            info['label']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? _orange : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            info['sublabel']!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
          'સમય / Duration',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _durationInfo.entries.map((entry) {
            final isSelected = _selectedDuration == entry.key;
            final info = entry.value;
            return GestureDetector(
              onTap: () => setState(() => _selectedDuration = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _orange : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _orange : AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      info['label']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      info['sublabel']!,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFarmerBody() {
    final fareEstimate = _fareEstimate();
    final canSearch = _selectedVehicleType != null && _selectedDuration != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Location card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _orangeSurface,
                      shape: BoxShape.circle,
                    ),
                    child: _isGettingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _orange,
                            ),
                          )
                        : const Icon(Icons.location_pin, color: _orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pickup / ઉઠાવ સ્થાન',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _locationLabel(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchCurrentLocation,
                    icon: const Icon(Icons.refresh, size: 20, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          _buildVehicleTypeSelector(),
          const SizedBox(height: 16),
          _buildDurationSelector(),

          const SizedBox(height: 16),

          // Load description
          TextField(
            controller: _loadDescriptionController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText:
                  'શું લઈ જવાનું છે? (વૈકલ્પિક) / What to carry? (optional)\nShakbhaji, fertilizer, goods...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                borderSide: const BorderSide(color: _orange, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),

          // Fare estimate
          if (fareEstimate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _orangeSurface,
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
              ),
              child: Row(
                children: [
                  const Icon(Icons.currency_rupee, color: _orange, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Estimated / અંદાજ:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '₹${fareEstimate.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: _orange,
                    ),
                  ),
                  const Text(
                    ' (paid directly to owner)',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: (canSearch && !_isSearching) ? _searchVehicles : null,
            icon: _isSearching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search),
            label: const Text(
              'વાહન શોધો / Find Vehicle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(AppSizes.largeButtonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
              ),
              disabledBackgroundColor: _orange.withValues(alpha: 0.4),
              disabledForegroundColor: Colors.white,
            ),
          ),

          if (kDebugMode) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addTestVehicles,
              icon: const Icon(Icons.bug_report, size: 18),
              label: const Text('Add Test Vehicles (Debug)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ],

          const SizedBox(height: 20),

          if (!_hasVehicleRegistered)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _orangeSurface,
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                border: Border.all(color: _orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping, color: _orange, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'વાહન માલિક? / Own a vehicle?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Register to earn with GaamHaul',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _openRegisterScreen,
                    style: TextButton.styleFrom(foregroundColor: _orange),
                    child: const Text(
                      'નોંધો / Register',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
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
          title: const Text('GaamHaul', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasVehicleRegistered && !_showFarmerView && _ownerDocId != null) {
      return VehicleOwnerDashboard(
        vehicleDocId: _ownerDocId!,
        onSwitchToSearch: () => setState(() => _showFarmerView = true),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GaamHaul', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Farm & Village Logistics',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_hasVehicleRegistered)
            TextButton.icon(
              onPressed: () => setState(() => _showFarmerView = false),
              icon: const Icon(Icons.dashboard, color: Colors.white, size: 18),
              label: const Text(
                'Dashboard',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _buildFarmerBody(),
    );
  }
}
