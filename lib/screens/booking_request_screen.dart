import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/booking_models.dart';
import '../services/booking_service.dart';
import '../utils/constants.dart';

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({
    required this.bookingId,
    required this.fromVillage,
    required this.toVillage,
    required this.type,
    this.distanceKm,
    super.key,
  });

  final String bookingId;
  final String fromVillage;
  final String toVillage;
  final String type;
  final double? distanceKm;

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  Timer? _timeoutTimer;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 60), _autoReject);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _autoReject() async {
    await _respond(false);
  }

  Future<String> _currentSaathiId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 'saathi';
    }

    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      return user.phoneNumber!;
    }

    final profile = await FirebaseFirestore.instance
        .collection('saathi')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (profile.docs.isNotEmpty) {
      final phone = profile.docs.first.data()['phone']?.toString().trim();
      if (phone != null && phone.isNotEmpty) {
        return phone;
      }
    }

    return user.uid;
  }

  Future<String> _currentSaathiName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 'Gaam Saathi';
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['displayName']?.toString().trim();
    if (userName != null && userName.isNotEmpty) {
      return userName;
    }

    final profile = await FirebaseFirestore.instance
        .collection('saathi')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (profile.docs.isNotEmpty) {
      final name = profile.docs.first.data()['name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }

    return 'Gaam Saathi';
  }

  Future<void> _respond(bool accept) async {
    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final saathiId = await _currentSaathiId();
      final saathiName = await _currentSaathiName();

      await BookingService.respondToBookingRequest(
        bookingId: widget.bookingId,
        accept: accept,
        saathiId: saathiId,
        saathiName: saathiName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Ride accepted' : 'Ride rejected'),
        ),
      );
      Navigator.of(context).maybePop();
    } on AlreadyAcceptedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This booking has already been handled.')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update booking: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Request'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data();
          final status = data?['status']?.toString() ?? BookingStatus.pending;
          final resolvedFromVillage = data?['fromVillage']?.toString() ?? widget.fromVillage;
          final resolvedToVillage = data?['destinationVillage']?.toString() ?? widget.toVillage;
          final resolvedType = data?['type']?.toString() ?? widget.type;
          final pickupLat = (data?['pickupLat'] as num?)?.toDouble();
          final pickupLng = (data?['pickupLng'] as num?)?.toDouble();

          if (status == BookingStatus.accepted) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This request is already accepted.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (status == BookingStatus.rejected) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This request was rejected.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final distanceLabel = widget.distanceKm != null
              ? '${widget.distanceKm!.toStringAsFixed(1)} km'
              : 'Unavailable';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.largePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'New Ride Request',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow('From', resolvedFromVillage),
                        _buildDetailRow('To', resolvedToVillage),
                        _buildDetailRow('Type', resolvedType),
                        _buildDetailRow('Distance', distanceLabel),
                        if (pickupLat != null && pickupLng != null)
                          _buildDetailRow(
                            'Pickup',
                            '${pickupLat.toStringAsFixed(4)}, ${pickupLng.toStringAsFixed(4)}',
                          ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isUpdating ? null : () => _respond(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isUpdating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isUpdating ? null : () => _respond(false),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'This request will auto-reject after 60 seconds if you do not respond.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}