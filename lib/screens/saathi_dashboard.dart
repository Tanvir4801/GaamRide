import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/booking_models.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import 'saathi_register_screen.dart';
import 'home_screen.dart' as home;

class GaamSaathiDashboard extends StatefulWidget {
  const GaamSaathiDashboard({
    required this.phone,
    super.key,
  });

  final String phone;

  @override
  State<GaamSaathiDashboard> createState() => _GaamSaathiDashboardState();
}

class _GaamSaathiDashboardState extends State<GaamSaathiDashboard> {
  bool _isUpdatingAvailability = false;
  String? _updatingBookingId;
  String? _updatingVehicleType;

  @override
  void initState() {
    super.initState();
    _ensureLocationPermission();
  }

  Future<void> _ensureLocationPermission() async {
    final granted = await LocationService.ensureLocationPermission();
    if (!mounted || granted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Location permission required for live updates / લાઇવ અપડેટ માટે લોકેશન પરમિશન જરૂરી છે',
        ),
      ),
    );
  }

  @override
  void dispose() {
    LocationService.stopSaathiLiveLocation(saathiId: widget.phone);
    super.dispose();
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.largePadding),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.largePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 36, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 16),
                  action,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateAvailability({
    required bool isAvailable,
    required String vehicleType,
  }) async {
    if (_isUpdatingAvailability) {
      return;
    }

    setState(() {
      _isUpdatingAvailability = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('saathi')
          .doc(widget.phone)
          .update({
        'isAvailable': isAvailable,
      });

      if (isAvailable) {
        await LocationService.startSaathiLiveLocation(
          saathiId: widget.phone,
          vehicleType: vehicleType,
        );
      } else {
        await LocationService.stopSaathiLiveLocation(saathiId: widget.phone);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAvailable
                ? 'Now available for rides / હવે રાઇડ માટે ઉપલબ્ધ'
                : 'Currently unavailable / હાલમાં ઉપલબ્ધ નથી',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to update availability'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update availability'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAvailability = false;
        });
      }
    }
  }

  Future<void> _updateVehicleType(String vehicleType) async {
    if (_updatingVehicleType != null) {
      return;
    }

    setState(() {
      _updatingVehicleType = vehicleType;
    });

    try {
      await FirebaseFirestore.instance
          .collection('saathi')
          .doc(widget.phone)
          .update({
        'vehicleType': vehicleType,
        'vehicleUpdatedAt': FieldValue.serverTimestamp(),
      });

      final doc = await FirebaseFirestore.instance
          .collection('saathi')
          .doc(widget.phone)
          .get();
      final isAvailable = doc.data()?['isAvailable'] as bool? ?? false;

      if (isAvailable) {
        await LocationService.startSaathiLiveLocation(
          saathiId: widget.phone,
          vehicleType: vehicleType,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle updated to $vehicleType / વાહન $vehicleType કર્યું'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to update vehicle'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update vehicle'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingVehicleType = null;
        });
      }
    }
  }

  Future<void> _updateCurrentLocation(String location) async {
    if (_isUpdatingAvailability) {
      return;
    }

    setState(() {
      _isUpdatingAvailability = true;
    });

    try {
      await FirebaseFirestore.instance.collection('saathi').doc(widget.phone).update({
        'currentLocation': location,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Current location updated to $location'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to update location'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update location'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAvailability = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const home.HomeScreen()),
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respondToBooking({
    required String bookingId,
    required bool accept,
    required String saathiName,
  }) async {
    if (_updatingBookingId != null) {
      return;
    }

    setState(() {
      _updatingBookingId = bookingId;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? widget.phone;

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': accept ? BookingStatus.accepted : BookingStatus.rejected,
        'driverId': accept ? currentUserId : null,
        'saathiId': accept ? widget.phone : null,
        'saathiName': accept ? saathiName : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Ride accepted / રાઇડ સ્વીકારી'
                : 'Ride rejected / રાઇડ નકારી',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to update request'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update request'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingBookingId = null;
        });
      }
    }
  }

  Widget _buildIncomingRideRequestCard(String saathiName) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('saathis')
          .doc(widget.phone)
          .snapshots(),
      builder: (context, saathiSnapshot) {
        GeoPoint? driverGeoPoint;
        final saathiData = saathiSnapshot.data?.data();
        final position = saathiData?['position'];
        if (position is Map<String, dynamic>) {
          final geo = position['geopoint'];
          if (geo is GeoPoint) {
            driverGeoPoint = geo;
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('status', isEqualTo: BookingStatus.pending)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Card(
                margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.defaultPadding),
                  child: Text(
                    'Failed to load booking requests: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.defaultPadding),
                  child: const Text(
                    'હાલમાં કોઈ નવી વિનંતી નથી / No pending booking requests',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }

            final bookings = [...snapshot.data!.docs];
            bookings.sort((a, b) {
              final aTs = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bTs = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bTs.compareTo(aTs);
            });

            return Column(
              children: bookings.map((booking) {
                final bookingData = booking.data();
                final destinationVillage =
                    (bookingData['destinationVillage'] ?? '').toString();
                final pickupLat = (bookingData['pickupLat'] as num?)?.toDouble();
                final pickupLng = (bookingData['pickupLng'] as num?)?.toDouble();
                final isUpdating = _updatingBookingId == booking.id;

                String distanceLabel = 'Distance unavailable';
                if (pickupLat != null && pickupLng != null && driverGeoPoint != null) {
                  final meters = Geolocator.distanceBetween(
                    driverGeoPoint.latitude,
                    driverGeoPoint.longitude,
                    pickupLat,
                    pickupLng,
                  );
                  distanceLabel = '${(meters / 1000).toStringAsFixed(1)} km';
                }

                return Card(
                  margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                  elevation: 4,
                  color: AppColors.secondary.withAlpha(24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notifications_active, color: AppColors.secondary),
                            SizedBox(width: 8),
                            Text(
                              'નવી રાઇડ વિનંતી / New Ride Request',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pickup: ${pickupLat?.toStringAsFixed(4) ?? '-'}, ${pickupLng?.toStringAsFixed(4) ?? '-'}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Destination: $destinationVillage',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Distance: $distanceLabel',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: isUpdating
                                    ? null
                                    : () => _respondToBooking(
                                          bookingId: booking.id,
                                          accept: true,
                                          saathiName: saathiName,
                                        ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                ),
                                child: isUpdating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isUpdating
                                    ? null
                                    : () => _respondToBooking(
                                          bookingId: booking.id,
                                          accept: false,
                                          saathiName: saathiName,
                                        ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.error),
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gaam Saathi Dashboard'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('saathi')
                .doc(widget.phone)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildStatusCard(
                  icon: Icons.hourglass_top,
                  title: 'Loading Dashboard',
                  message: 'Fetching your Gaam Saathi profile...',
                  action: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildStatusCard(
                  icon: Icons.error_outline,
                  title: 'Unable to Load Profile',
                  message: 'Please try again in a moment.\n${snapshot.error}',
                );
              }

              final doc = snapshot.data;
              final data = doc?.data();

              if (doc == null || !doc.exists || data == null) {
                return _buildStatusCard(
                  icon: Icons.person_add_alt_1,
                  title: 'Profile Not Found',
                  message:
                      'Your Gaam Saathi profile is missing. Complete registration to continue.',
                  action: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => GaamSaathiRegisterScreen(
                            phone: widget.phone,
                          ),
                        ),
                      );
                    },
                    child: const Text('Complete Registration'),
                  ),
                );
              }

              final name = data['name'] as String? ?? '-';
              final village = data['village'] as String? ?? '-';
              final vehicleType = data['vehicleType'] as String? ?? '-';
              final rating = (data['rating'] as num?)?.toDouble() ?? 0;
              final isAvailable = data['isAvailable'] as bool? ?? false;
              final verified = data['verified'] as bool? ?? false;
              final currentLocation = data['currentLocation'] as String? ?? 'Highway';

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.largePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  _buildIncomingRideRequestCard(name),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.largePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  village,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_car,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                vehicleType,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: AppConstants.locationOptions.contains(currentLocation)
                                ? currentLocation
                                : 'Highway',
                            decoration: InputDecoration(
                              labelText: 'Current Location',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                              ),
                            ),
                            items: AppConstants.locationOptions
                                .map(
                                  (location) => DropdownMenuItem<String>(
                                    value: location,
                                    child: Text(location),
                                  ),
                                )
                                .toList(),
                            onChanged: _isUpdatingAvailability
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    _updateCurrentLocation(value);
                                  },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: AppColors.secondary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${rating.toStringAsFixed(1)} ★',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.defaultPadding),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(24),
                      borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place, color: AppColors.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Current location: $currentLocation',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.largePadding,
                        vertical: AppSizes.defaultPadding,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available for Ride',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAvailable ? 'You are online' : 'You are offline',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isAvailable
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: isAvailable,
                            onChanged: _isUpdatingAvailability
                                ? null
                                : (value) => _updateAvailability(
                                      isAvailable: value,
                                      vehicleType: vehicleType,
                                    ),
                            activeColor: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.largePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vehicle Type / વાહન પ્રકાર',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select the vehicle you are using now.',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: AppConstants.vehicleTypes.map((type) {
                              final selected = vehicleType == type;
                              final loading = _updatingVehicleType == type;

                              return ChoiceChip(
                                label: loading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(type),
                                selected: selected,
                                onSelected: _isUpdatingAvailability || loading
                                    ? null
                                    : (_) => _updateVehicleType(type),
                                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                backgroundColor: Colors.white,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.defaultPadding),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Status',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          verified ? 'Verified' : 'Pending Verification',
                          style: TextStyle(
                            fontSize: 14,
                            color: verified ? AppColors.success : AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_isUpdatingAvailability)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Updating availability...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
