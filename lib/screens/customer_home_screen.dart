import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import '../utils/fare_calculator.dart';
import 'booking_search_screen.dart';
import 'home_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  LatLng? _currentLocation;
  VillageLocation? _nearestVillage;
  VillageLocation? _selectedDestination;

  bool _isGettingLocation = true;
  bool _isSearching = false;
  bool _searched = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationError = AppConstants.enableLocationMessage;
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
          _locationError = permission == LocationPermission.deniedForever
              ? 'Location permanently denied. Enable from Settings.\nLocation Settings > GaamRide > Allow'
              : 'Location permission denied / લોકેશન પરવાનગી નકારાઈ.';
          _isGettingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);
      final nearestVillage = LocationService.getNearestVillage(currentLocation);

      if (!mounted) return;
      setState(() {
        _currentLocation = currentLocation;
        _nearestVillage = nearestVillage;
        _isGettingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Unable to fetch location / સ્થાન મેળવવામાં ભૂલ';
        _isGettingLocation = false;
      });
    }
  }

  String _pickupLabel() {
    if (_locationError != null) return _locationError!;
    if (_isGettingLocation) return 'Detecting... / શોધી રહ્યા છીએ...';
    if (_currentLocation == null) return 'Location unavailable';
    final v = _nearestVillage ?? LocationService.getNearestVillage(_currentLocation!);
    return v != null ? '${v.nameGu} (${v.name})' : 'Current GPS location';
  }

  String _destinationLabel() {
    final d = _selectedDestination;
    return d == null ? 'ગામ પસંદ કરો / Select Village' : '${d.nameGu} (${d.name})';
  }

  double? _estimatedFare() {
    if (_currentLocation == null || _selectedDestination == null) return null;
    final distKm = Geolocator.distanceBetween(
      _currentLocation!.latitude, _currentLocation!.longitude,
      _selectedDestination!.lat, _selectedDestination!.lng,
    ) / 1000;
    return FareCalculator.calculateRideFare(distKm);
  }

  Future<void> _showVillageSelectorSheet() async {
    final currentVillage = _nearestVillage;
    final villages = [...LocationService.approvedVillages]
      ..sort((a, b) => a.name.compareTo(b.name));

    String searchQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = villages.where((v) {
              final q = searchQuery.toLowerCase();
              return q.isEmpty ||
                  v.name.toLowerCase().contains(q) ||
                  v.nameGu.toLowerCase().contains(q);
            }).toList();

            return SafeArea(
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.78,
                minChildSize: 0.50,
                maxChildSize: 0.92,
                builder: (context, scrollController) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'ક્યાં જવું છે? / Where to go?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (v) => setModalState(() => searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'ગામ શોધો / Search village',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final village = filtered[index];
                              final isCurrent = currentVillage?.name == village.name;
                              final isSelected = _selectedDestination?.name == village.name;

                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.black12,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                tileColor: isSelected
                                    ? AppColors.primarySurface
                                    : Colors.white,
                                leading: CircleAvatar(
                                  backgroundColor: isCurrent
                                      ? AppColors.primarySurface
                                      : Colors.grey.shade100,
                                  child: Icon(
                                    isCurrent
                                        ? Icons.my_location
                                        : Icons.location_city,
                                    color: isCurrent
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  village.nameGu,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(village.name),
                                trailing: isCurrent
                                    ? const Chip(
                                        label: Text(
                                          'Current',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        padding: EdgeInsets.zero,
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  if (isCurrent) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      const SnackBar(
                                        content: Text('તમે પહેલેથી ત્યાં છો!'),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _selectedDestination = village;
                                    _searched = false;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _findSaathi() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS location not detected yet / GPS સ્થાન હજુ મળ્યું નથી')),
      );
      return;
    }
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('પહેલાં ગામ પસંદ કરો / Select destination first')),
      );
      return;
    }
    if (_nearestVillage?.name == _selectedDestination!.name) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('તમે પહેલેથી ત્યાં છો!')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searched = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
      final distKm = Geolocator.distanceBetween(
        _currentLocation!.latitude, _currentLocation!.longitude,
        _selectedDestination!.lat, _selectedDestination!.lng,
      ) / 1000;
      final fare = FareCalculator.calculateRideFare(distKm);

      final result = await BookingService.createBookingAndDispatch(
        input: CreateBookingInput(
          type: BookingType.ride,
          userId: userId,
          customerName: user?.displayName ?? '',
          customerPhone: user?.phoneNumber ?? '',
          pickupLat: _currentLocation!.latitude,
          pickupLng: _currentLocation!.longitude,
          destinationVillage: _selectedDestination!.name,
          radiusKm: 5,
          fare: fare,
        ),
      );

      if (!mounted) return;
      setState(() => _isSearching = false);

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingSearchScreen(
            bookingId: result.bookingId,
            type: BookingType.ride,
            primaryColor: AppColors.primary,
            pickupLocation: _currentLocation,
            destinationVillage: _selectedDestination!.name,
            otp: result.otp,
            fare: result.fare,
          ),
        ),
      );

      if (!mounted) return;
      setState(() => _searched = false);
    } on NoDriversFoundException {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searched = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('કોઈ સાથી ઉપલબ્ધ નથી. ફરી પ્રયાસ કરો. / No Saathis found nearby.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searched = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ભૂલ / Error: $e')),
      );
    }
  }

  Future<void> _setDebugLocation(VillageLocation village) async {
    if (!kDebugMode) return;
    setState(() {
      _currentLocation = LatLng(village.lat, village.lng);
      _nearestVillage = village;
      _locationError = null;
      _searched = false;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSearch = !_isGettingLocation &&
        _currentLocation != null &&
        _selectedDestination != null;
    final fare = _estimatedFare();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GaamRide', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Mahuva Taluka Transport',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
            );
          },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (kDebugMode)
            IconButton(
              onPressed: () => _showDebugLocationSheet(),
              icon: const Icon(Icons.bug_report),
              tooltip: 'Set Test Location',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pickup card
              _buildLocationCard(
                label: 'તમારું સ્થાન / Your Location',
                value: _pickupLabel(),
                icon: Icons.my_location,
                iconColor: AppColors.primary,
                iconBg: AppColors.primarySurface,
                onRefresh: _fetchCurrentLocation,
                isLoading: _isGettingLocation,
              ),

              // Arrow
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: Icon(Icons.arrow_downward, color: AppColors.textSecondary),
                ),
              ),

              // Destination card
              GestureDetector(
                onTap: _showVillageSelectorSheet,
                child: _buildLocationCard(
                  label: 'ક્યાં જવું છે? / Where to go?',
                  value: _destinationLabel(),
                  icon: Icons.flag_rounded,
                  iconColor: const Color(0xFFE65100),
                  iconBg: const Color(0xFFFBE9E7),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ),
              ),

              // Fare estimate
              if (fare != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_rupee, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Estimated Fare / અંદાજિત ભાડું:',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${fare.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Find Saathi button
              ElevatedButton.icon(
                onPressed: canSearch && !_isSearching ? _findSaathi : null,
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
                  'સાથી શોધો / Find Saathi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(AppSizes.largeButtonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // Instructions / status
              if (!_searched && !_isSearching)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      const Text(
                        'ગામ પસંદ કરો અને "સાથી શોધો" ટૅપ કરો',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select destination and tap Find Saathi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isSearching)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    VoidCallback? onRefresh,
    bool isLoading = false,
    Widget? trailing,
  }) {
    return Card(
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
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onRefresh != null && !isLoading)
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 20, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _showDebugLocationSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Set Test Location (Debug)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...LocationService.approvedVillages.map(
                (village) => ListTile(
                  leading: const Icon(Icons.location_on, color: AppColors.primary),
                  title: Text('${village.nameGu} (${village.name})'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _setDebugLocation(village);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
