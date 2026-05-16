import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/constants.dart';

class NearbyHaulVehicle {
  const NearbyHaulVehicle({
    required this.id,
    required this.ownerName,
    required this.phone,
    required this.vehicleType,
    required this.capacity,
    required this.ratePerHour,
    required this.distanceKm,
    required this.etaMinutes,
    required this.villageName,
  });

  final String id;
  final String ownerName;
  final String phone;
  final String vehicleType;
  final String capacity;
  final int ratePerHour;
  final double distanceKm;
  final int etaMinutes;
  final String villageName;
}

class HaulVehicleCard extends StatelessWidget {
  const HaulVehicleCard({
    required this.vehicle,
    required this.durationLabel,
    required this.userVillageName,
    this.loadDescription,
    super.key,
  });

  final NearbyHaulVehicle vehicle;
  final String durationLabel;
  final String userVillageName;
  final String? loadDescription;

  String _vehicleTypeLabel(String value) {
    switch (value) {
      case 'mini_tempo':
        return 'મિની ટેમ્પો';
      case 'pickup':
        return 'પિકઅપ ટ્રક';
      case 'tractor':
        return 'ટ્રેક્ટર';
      default:
        return value;
    }
  }

  String _capacityLabel(String value) {
    if (value.endsWith('+')) {
      return '$value કિગ્રા+';
    }
    return '$value સુધી';
  }

  Future<void> _callOwner() async {
    if (vehicle.phone.isEmpty) return;

    final uri = Uri.parse('tel:+91${vehicle.phone}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsappOwner() async {
    if (vehicle.phone.isEmpty) return;

    final loadText = (loadDescription ?? '').trim();
    final message =
        'નમસ્તે ${vehicle.ownerName}ભાઈ, મારે ${_vehicleTypeLabel(vehicle.vehicleType)} $durationLabel માટે જોઈએ છે. '
        '${loadText.isEmpty ? '' : '$loadText\n'}'
        'સ્થાન: $userVillageName\n'
        'શું તમે ઉપલબ્ધ છો? — GaamHaul App';

    final uri = Uri.parse(
      'https://wa.me/91${vehicle.phone}?text=${Uri.encodeComponent(message)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final distanceText =
        '${vehicle.distanceKm.toStringAsFixed(1)} કિમી દૂર · ~${vehicle.etaMinutes} મિનિટ';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle.ownerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _vehicleTypeLabel(vehicle.vehicleType),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.scale, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  _capacityLabel(vehicle.capacity),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.currency_rupee,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 2),
                Text(
                  '${vehicle.ratePerHour}/કલાક',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              distanceText,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: vehicle.phone.isEmpty ? null : _callOwner,
                    icon: const Icon(Icons.call, color: Colors.green),
                    label: const Text('કૉલ કરો'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: vehicle.phone.isEmpty ? null : _whatsappOwner,
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}