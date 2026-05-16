import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
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
          _locationError = 'Location service is disabled. / સ્થાન સેવા બંધ છે.';
          _isGettingLocation = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _locationError = 'Location permission denied. / લોકેશન પરવાનગી નકારાઈ.';
          _isGettingLocation = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationError =
              'Location permission permanently denied. Enable it from settings. / લોકેશન પરવાનગી કાયમ માટે બંધ છે. સેટિંગ્સમાં ચાલુ કરો.';
          _isGettingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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
        _locationError = 'Unable to fetch current location. / વર્તમાન સ્થાન મેળવવામાં નિષ્ફળ.';
        _isGettingLocation = false;
      });
    }
  }

  String _pickupLabel() {
    if (_locationError != null) {
      return _locationError!;
    }

    final currentLocation = _currentLocation;
    if (_isGettingLocation) {
      return 'Detecting... / શોધી રહ્યા છીએ...';
    }

    if (currentLocation == null) {
      return 'Current location unavailable';
    }

    final nearestVillage = _nearestVillage ??
        LocationService.getNearestVillage(currentLocation);

    if (nearestVillage != null) {
      return '${nearestVillage.nameGu} (${nearestVillage.name}) વિસ્તાર';
    }

    return '${currentLocation.latitude.toStringAsFixed(5)}, ${currentLocation.longitude.toStringAsFixed(5)}';
  }

  String _destinationLabel() {
    final destination = _selectedDestination;
    if (destination == null) {
      return 'ગામ પસંદ કરો / Select Village';
    }

    return '${destination.nameGu} (${destination.name})';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredVillages = villages.where((village) {
              final query = searchQuery.toLowerCase();
              return query.isEmpty ||
                  village.name.toLowerCase().contains(query) ||
                  village.nameGu.toLowerCase().contains(query);
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
                            width: 48,
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
                          onChanged: (value) {
                            setModalState(() {
                              searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search village / ગામ શોધો',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.buttonRadius),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${filteredVillages.length} villages available / ${filteredVillages.length} ગામ ઉપલબ્ધ',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: filteredVillages.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final village = filteredVillages[index];
                              final isSameAsCurrent = currentVillage != null &&
                                  village.name == currentVillage.name;

                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Colors.black12),
                                ),
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.location_city,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  '${village.nameGu} (${village.name})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'Lat: ${village.lat.toStringAsFixed(4)}, Lng: ${village.lng.toStringAsFixed(4)}',
                                ),
                                onTap: () {
                                  if (isSameAsCurrent) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text('તમે પહેલેથી ત્યાં છો!'),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.pop(context);
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

  Future<void> _showDebugLocationSheet() async {
    final debugVillages = LocationService.approvedVillages.where((village) {
      return village.name == 'Anaval' ||
          village.name == 'Kos' ||
          village.name == 'Tarkani';
    }).toList();

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Set Test Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...debugVillages.map(
                (village) => ListTile(
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

  Future<void> _findSaathi() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS location not detected yet / GPS સ્થાન હજુ મળ્યું નથી'),
        ),
      );
      return;
    }

    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('પહેલાં ગામ પસંદ કરો')),
      );
      return;
    }

    if (_nearestVillage != null &&
        _selectedDestination!.name == _nearestVillage!.name) {
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
      final userId = FirebaseAuth.instance.currentUser?.uid ??
          'guest_${DateTime.now().millisecondsSinceEpoch}';

      final result = await BookingService.createBookingAndDispatch(
        input: CreateBookingInput(
          type: BookingType.ride,
          userId: userId,
          pickupLat: _currentLocation!.latitude,
          pickupLng: _currentLocation!.longitude,
          destinationVillage: _selectedDestination!.name,
          radiusKm: 5,
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
            type: BookingType.ride,
            primaryColor: AppColors.primary,
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
          content: Text(
            'કોઈ સાથી ઉપલબ્ધ નથી. ફરી પ્રયાસ કરો. / No drivers found, please retry.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searched = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('નેટવર્ક ભૂલ / Search failed: $e')),
      );
    }
  }

  Widget _buildPickupCard() {
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
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_pin,
                color: Colors.green,
              ),
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
                    _pickupLabel(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (!_isGettingLocation && _currentLocation != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_currentLocation!.latitude.toStringAsFixed(5)}, ${_currentLocation!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard() {
    return GestureDetector(
      onTap: _showVillageSelectorSheet,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.defaultPadding),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ક્યાં જવું છે? / Where to go?',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _destinationLabel(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (!_searched) {
      return const Center(
        child: Text(
          'ગામ પસંદ કરો અને પછી સાથી શોધો\nSelect destination and tap Find Saathi',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    return const Center(
      child: Text(
        'બુકિંગ સ્ટેટસ ખુલશે...\nOpening booking status...',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSearch = !_isGettingLocation &&
        _currentLocation != null &&
        _selectedDestination != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Gaam Saathi'),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      floatingActionButton: kDebugMode
          ? FloatingActionButton.extended(
              onPressed: _showDebugLocationSheet,
              icon: const Icon(Icons.bug_report),
              label: const Text('Set Test Location'),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.largePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPickupCard(),
              const SizedBox(height: 12),
              const Center(
                child: Icon(
                  Icons.arrow_downward,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDestinationCard(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: canSearch
                    ? _findSaathi
                    : () {
                        if (_currentLocation == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'સ્થાન હજી મળ્યું નથી / Location not detected yet',
                              ),
                            ),
                          );
                          return;
                        }
                        if (_selectedDestination == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('પહેલાં ગામ પસંદ કરો')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(AppSizes.largeButtonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                child: const Text(
                  'સાથી શોધો / Find Saathi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildResultsSection()),
            ],
          ),
        ),
      ),
    );
  }
}