import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'main_shell.dart';
import 'otp_verification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  bool _isSendingOtp = false;

  Future<void> _openSaathiLogin() async {
    final phoneController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Gaam Saathi Login'),
          content: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter 10 digit mobile number',
              prefixText: '+91 ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final rawPhone = phoneController.text.trim();
                if (rawPhone.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext);

                setState(() {
                  _isSendingOtp = true;
                });

                try {
                  final normalizedPhone = rawPhone.startsWith('+91')
                      ? rawPhone
                      : '+91$rawPhone';

                  final verificationId = await _authService.sendOtp(
                    phone: normalizedPhone,
                    onCodeSent: (_) {},
                  );

                  if (!mounted) return;
                  setState(() {
                    _isSendingOtp = false;
                  });

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OtpVerificationScreen(
                        verificationId: verificationId,
                        phoneNumber: normalizedPhone,
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  setState(() {
                    _isSendingOtp = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send OTP: $e')),
                  );
                }
              },
              child: const Text('Send OTP'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.largePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Village Transport at Your Fingertips',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(AppSizes.largeButtonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const MainShell(),
                    ),
                  );
                },
                child: const Text(
                  'Continue as Customer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size.fromHeight(AppSizes.largeButtonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                onPressed: _isSendingOtp ? null : _openSaathiLogin,
                child: _isSendingOtp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Become a Gaam Saathi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
