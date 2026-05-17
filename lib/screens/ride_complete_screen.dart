import 'package:flutter/material.dart';

import '../services/booking_service.dart';
import '../utils/constants.dart';
import 'main_shell.dart';

class RideCompleteScreen extends StatefulWidget {
  const RideCompleteScreen({
    required this.bookingId,
    required this.saathiId,
    required this.saathiName,
    required this.fare,
    super.key,
  });

  final String bookingId;
  final String saathiId;
  final String saathiName;
  final double fare;

  @override
  State<RideCompleteScreen> createState() => _RideCompleteScreenState();
}

class _RideCompleteScreenState extends State<RideCompleteScreen>
    with SingleTickerProviderStateMixin {
  int _selectedStars = 0;
  bool _submitting = false;
  bool _submitted = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_submitting || _selectedStars == 0) return;

    setState(() => _submitting = true);
    try {
      await BookingService.submitRating(
        bookingId: widget.bookingId,
        saathiId: widget.saathiId,
        stars: _selectedStars,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('રેટિંગ સેવ થયું નહીં, ફરી પ્રયાસ કરો')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.largePadding),
          child: Column(
            children: [
              const Spacer(),

              // Animated checkmark
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 60,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'સવારી પૂર્ણ!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'Ride Complete!',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // Fare card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ભાડું / Fare',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.saathiName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹${widget.fare.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Rating
              if (!_submitted) ...[
                const Text(
                  'સાથીને રેટ કરો / Rate your Saathi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedStars = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          _selectedStars >= star
                              ? Icons.star
                              : Icons.star_border,
                          color: AppColors.secondary,
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_selectedStars > 0 && !_submitting)
                        ? _submitRating
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize:
                          const Size.fromHeight(AppSizes.largeButtonHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.buttonRadius),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'રેટિંગ આપો / Submit Rating',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'રેટિંગ આપ્યું: $_selectedStars ⭐',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Go home button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.home),
                  label: const Text(
                    'ઘરે જાઓ / Go Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(AppSizes.largeButtonHeight),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
