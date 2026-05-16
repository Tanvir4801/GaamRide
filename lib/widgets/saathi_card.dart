import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';
import '../utils/constants.dart';

class SaathiCard extends StatelessWidget {
  const SaathiCard({
    required this.saathi,
    required this.selectedDestination,
    super.key,
  });

  final NearbySaathi saathi;
  final VillageLocation selectedDestination;

  Future<void> _callSaathi() async {
    if (saathi.phone.isEmpty) return;

    final uri = Uri.parse('tel:+91${saathi.phone}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsappSaathi() async {
    if (saathi.phone.isEmpty) return;

    final message =
        'નમસ્તે ${saathi.name}ભાઈ, મારે ${selectedDestination.nameGu} જવું છે. શું તમે અત્યારે ઉપલબ્ધ છો? - GaamRide';
    final uri = Uri.parse(
      'https://wa.me/91${saathi.phone}?text=${Uri.encodeComponent(message)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final distanceText =
        '${saathi.distanceKm.toStringAsFixed(1)} કિમી દૂર · ~${saathi.etaMinutes} મિનિટ';

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
                    saathi.name,
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
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    saathi.vehicleType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              distanceText,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saathi.phone.isEmpty ? null : _callSaathi,
                    icon: const Icon(Icons.phone),
                    label: const Text('કૉલ કરો'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: saathi.phone.isEmpty ? null : _whatsappSaathi,
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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