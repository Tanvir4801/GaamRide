import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/booking_models.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import 'home_screen.dart' as home;
import 'saathi_register_screen.dart';
import 'saathi_ride_screen.dart';

class GaamSaathiDashboard extends StatefulWidget {
  const GaamSaathiDashboard({required this.phone, super.key});

  final String phone;

  @override
  State<GaamSaathiDashboard> createState() => _GaamSaathiDashboardState();
}

class _GaamSaathiDashboardState extends State<GaamSaathiDashboard> {
  bool _isUpdatingAvailability = false;
  String? _updatingBookingId;
  String? _lastAlertedBookingId;

  @override
  void initState() {
    super.initState();
    _ensureLocationPermission();
  }

  @override
  void dispose() {
    LocationService.stopSaathiLiveLocation(saathiId: widget.phone);
    super.dispose();
  }

  Future<void> _ensureLocationPermission() async {
    final granted = await LocationService.ensureLocationPermission();
    if (!mounted || granted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Location permission required / લાઇવ અપડેટ માટે લોકેશન પરમિશન જરૂરી છે',
        ),
      ),
    );
  }

  Future<void> _updateAvailability({
    required bool isAvailable,
    required String vehicleType,
  }) async {
    if (_isUpdatingAvailability) return;

    setState(() => _isUpdatingAvailability = true);
    try {
      // Parallel: update saathis collection + start/stop live location
      await FirebaseFirestore.instance
          .collection(AppConstants.saathiCollection)
          .doc(widget.phone)
          .set({'isAvailable': isAvailable}, SetOptions(merge: true));

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
                ? 'Online! રાઇડ માટે ઉપલબ્ધ / Now available for rides'
                : 'Offline / ઑફલાઇન',
          ),
          backgroundColor:
              isAvailable ? AppColors.success : AppColors.textSecondary,
          duration: const Duration(seconds: 2),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Update failed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ઉપલબ્ધતા અપડેટ કરી શકાઈ નથી')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingAvailability = false);
    }
  }

  Future<void> _respondToBooking({
    required String bookingId,
    required bool accept,
    required String saathiName,
    String saathiPhone = '',
    double? pickupLat,
    double? pickupLng,
    String? customerName,
    String? customerPhone,
    String? destinationVillage,
    double? fare,
    String? otp,
  }) async {
    if (_updatingBookingId != null) return;

    setState(() => _updatingBookingId = bookingId);

    try {
      final currentUserId =
          FirebaseAuth.instance.currentUser?.uid ?? widget.phone;

      await FirebaseFirestore.instance
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .update({
        'status': accept ? BookingStatus.accepted : BookingStatus.rejected,
        'driverId': accept ? currentUserId : null,
        'saathiId': accept ? widget.phone : null,
        'saathiName': accept ? saathiName : null,
        'saathiPhone': accept ? saathiPhone : null,
        'acceptedAt': accept ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      if (accept) {
        HapticFeedback.mediumImpact();
        // Navigate to SaathiRideScreen
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SaathiRideScreen(
              bookingId: bookingId,
              saathiId: widget.phone,
              saathiName: saathiName,
              customerLat: pickupLat,
              customerLng: pickupLng,
              customerName: customerName,
              customerPhone: customerPhone,
              destinationVillage: destinationVillage,
              fareAmount: fare,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('રાઇડ નકારી / Ride rejected'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to update request')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request update failed')),
      );
    } finally {
      if (mounted) setState(() => _updatingBookingId = null);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await LocationService.stopSaathiLiveLocation(saathiId: widget.phone);
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const home.HomeScreen()),
      );
    }
  }

  Widget _buildOnlineToggle({
    required bool isAvailable,
    required String vehicleType,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(
          color: isAvailable ? AppColors.primary : AppColors.border,
          width: isAvailable ? 2 : 1,
        ),
      ),
      color: isAvailable ? AppColors.primarySurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color:
                    isAvailable ? AppColors.success : AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAvailable ? 'Online — રાઇડ મળી શકે' : 'Offline — ઑફલાઇન',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isAvailable
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAvailable
                        ? 'GPS live update active / GPS ચાલુ'
                        : 'Tap to go online',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              ignoring: _isUpdatingAvailability,
              child: Switch(
                value: isAvailable,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => _updateAvailability(
                  isAvailable: val,
                  vehicleType: vehicleType,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequests({
    required String saathiName,
    required GeoPoint? saathiGeoPoint,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.bookingsCollection)
          .where('status', isEqualTo: BookingStatus.pending)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Error loading requests: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.hourglass_empty,
                      size: 36, color: AppColors.textSecondary),
                  SizedBox(height: 8),
                  Text(
                    'હાલ કોઈ વિનંતી નથી',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'No pending ride requests',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data();
            final pickupLat = (data['pickupLat'] as num?)?.toDouble();
            final pickupLng = (data['pickupLng'] as num?)?.toDouble();
            final destination = (data['destinationVillage'] ?? '').toString();
            final customerName =
                (data['customerName'] ?? 'Customer').toString();
            final customerPhone = (data['customerPhone'] ?? '').toString();
            final fare = (data['fare'] as num?)?.toDouble();
            final otp = data['otp']?.toString();
            final isUpdating = _updatingBookingId == doc.id;

            String distanceLabel = '';
            if (pickupLat != null &&
                pickupLng != null &&
                saathiGeoPoint != null) {
              final m = Geolocator.distanceBetween(
                saathiGeoPoint.latitude,
                saathiGeoPoint.longitude,
                pickupLat,
                pickupLng,
              );
              distanceLabel = '${(m / 1000).toStringAsFixed(1)} km';
            }

            // Haptic alert for new requests
            if (_lastAlertedBookingId != doc.id) {
              _lastAlertedBookingId = doc.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                HapticFeedback.heavyImpact();
              });
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              color: AppColors.primarySurface,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'નવી સવારી વિનંતી / New Ride Request',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (fare != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '₹${fare.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _infoRow(Icons.person, customerName),
                    const SizedBox(height: 4),
                    _infoRow(Icons.flag,
                        destination.isEmpty ? 'Destination TBD' : destination),
                    if (distanceLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _infoRow(Icons.straighten, '$distanceLabel away'),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isUpdating
                                ? null
                                : () => _respondToBooking(
                                      bookingId: doc.id,
                                      accept: true,
                                      saathiName: saathiName,
                                      pickupLat: pickupLat,
                                      pickupLng: pickupLng,
                                      customerName: customerName,
                                      customerPhone: customerPhone,
                                      destinationVillage: destination,
                                      fare: fare,
                                      otp: otp,
                                    ),
                            icon: isUpdating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: const Text(
                              'સ્વીકારો / Accept',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppSizes.buttonRadius),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isUpdating
                                ? null
                                : () => _respondToBooking(
                                      bookingId: doc.id,
                                      accept: false,
                                      saathiName: saathiName,
                                    ),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text(
                              'નકારો / Reject',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              foregroundColor: AppColors.error,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppSizes.buttonRadius),
                              ),
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
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard({
    required String name,
    required String village,
    required String vehicleType,
    required double rating,
    required bool verified,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primarySurface,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (verified)
                        const Icon(
                          Icons.verified,
                          color: AppColors.primary,
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$vehicleType · $village',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: AppColors.secondary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.largePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Gaam Saathi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.saathiCollection)
            .doc(widget.phone)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildStatusCard(
              icon: Icons.hourglass_top,
              title: 'Loading...',
              message: 'Fetching your Gaam Saathi profile...',
              action: const CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildStatusCard(
              icon: Icons.error_outline,
              title: 'Unable to Load',
              message: 'Please check your connection and try again.',
            );
          }

          final doc = snapshot.data;
          final data = doc?.data();

          if (doc == null || !doc.exists || data == null) {
            return _buildStatusCard(
              icon: Icons.person_add_alt_1,
              title: 'Profile Not Found',
              message: 'Complete registration to continue.\nનોંધણી પૂર્ણ કરો.',
              action: ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GaamSaathiRegisterScreen(phone: widget.phone),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Complete Registration'),
              ),
            );
          }

          final name = data['name'] as String? ?? '-';
          final village = data['village'] as String? ?? '-';
          final vehicleType = data['vehicleType'] as String? ?? 'Vehicle';
          final rating = (data['rating'] as num?)?.toDouble() ?? 5.0;
          final isAvailable = data['isAvailable'] as bool? ?? false;
          final verified = data['verified'] as bool? ?? false;

          // Extract current saathi GeoPoint for distance calculations
          GeoPoint? saathiGeoPoint;
          final position = data['position'];
          if (position is Map<String, dynamic>) {
            final geo = position['geopoint'];
            if (geo is GeoPoint) saathiGeoPoint = geo;
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile card
                  _buildProfileCard(
                    name: name,
                    village: village,
                    vehicleType: vehicleType,
                    rating: rating,
                    verified: verified,
                  ),

                  const SizedBox(height: 12),

                  // Online/Offline toggle
                  _buildOnlineToggle(
                    isAvailable: isAvailable,
                    vehicleType: vehicleType,
                  ),

                  const SizedBox(height: 16),

                  // Incoming requests section
                  if (isAvailable) ...[
                    const Text(
                      'આવતી વિનંતીઓ / Incoming Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildIncomingRequests(
                      saathiName: name,
                      saathiGeoPoint: saathiGeoPoint,
                    ),
                  ] else ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.cardRadius),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.power_settings_new,
                              size: 36,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'ઑફલાઇન / Offline',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Go online to receive ride requests.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
