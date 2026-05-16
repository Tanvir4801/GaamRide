import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'auth_gate_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    required this.verificationId,
    required this.phoneNumber,
    this.debugBypass = false,
    super.key,
  });

  final String verificationId;
  final String phoneNumber;
  final bool debugBypass;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const String _firebaseTestOtp = '123456';
  static const int _resendCooldownSeconds = 30;

  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  bool _navigated = false;
  String? _errorMessage;
  int _secondsUntilResend = _resendCooldownSeconds;
  Timer? _resendTimer;
  late String _activeVerificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _activeVerificationId = widget.verificationId;
    if (!widget.debugBypass) {
      _startResendTimer();
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _secondsUntilResend = _resendCooldownSeconds;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() {
          _secondsUntilResend = 0;
        });
      } else {
        setState(() {
          _secondsUntilResend -= 1;
        });
      }
    });
  }

  bool _validateOtp() {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      setState(() {
        _errorMessage = ValidationText.emptyOtp;
      });
      return false;
    }

    if (otp.length != 6) {
      setState(() {
        _errorMessage = ValidationText.invalidOtp;
      });
      return false;
    }

    setState(() {
      _errorMessage = null;
    });
    return true;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _checkUserAndNavigate({String? fallbackPhone}) async {
    if (_navigated || !mounted) {
      return;
    }

    try {
      if (!mounted) return;
      _navigated = true;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const AuthGateScreen(),
        ),
        (route) => false,
      );
    } on FirebaseException catch (e) {
      debugPrint('otp checkUserAndNavigate FirebaseException: ${e.code} ${e.message}');
      _showError(e.message ?? 'Failed to continue login flow.');
    } catch (e) {
      debugPrint('otp checkUserAndNavigate error: $e');
      _showError('Something went wrong while continuing login.');
    }
  }

  Future<void> _verifyOtp() async {
    if (!_validateOtp()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.debugBypass) {
        if (_otpController.text.trim() != _firebaseTestOtp) {
          setState(() {
            _errorMessage = 'Invalid OTP. Use 123456 in simulator mode.';
          });
          _showError(_errorMessage!);
          return;
        }

        debugPrint('verifyOtp: debug bypass success');
        await _checkUserAndNavigate(fallbackPhone: widget.phoneNumber);
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _activeVerificationId,
        smsCode: _otpController.text.trim(),
      );

      debugPrint('verifyOtp: attempting Firebase signInWithCredential');
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      await _checkUserAndNavigate(fallbackPhone: widget.phoneNumber);
    } on FirebaseAuthException catch (e) {
      debugPrint('verifyOtp FirebaseAuthException: ${e.code} ${e.message}');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message ?? 'OTP verification failed. Try again.';
      });
      _showError(_errorMessage!);
    } catch (e) {
      debugPrint('verifyOtp error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'OTP verification failed. Try again.';
      });
      _showError(_errorMessage!);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (widget.debugBypass) {
      _showError('Simulator mode is active. Use OTP 123456.');
      return;
    }

    if (_isResending || _isLoading || _secondsUntilResend > 0) {
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    debugPrint('resendOtp: requesting OTP resend for ${widget.phoneNumber}');

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (!mounted) return;
            await _checkUserAndNavigate(fallbackPhone: widget.phoneNumber);
          } on FirebaseAuthException catch (e) {
            debugPrint('resendOtp verificationCompleted FirebaseAuthException: ${e.code} ${e.message}');
            if (!mounted) return;
            _showError(e.message ?? 'Auto verification failed.');
          } catch (e) {
            debugPrint('resendOtp verificationCompleted error: $e');
            if (!mounted) return;
            _showError('Auto verification failed. Please enter OTP manually.');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('resendOtp verificationFailed: ${e.code} ${e.message}');
          if (!mounted) return;
          setState(() {
            _errorMessage = e.message ?? 'Failed to resend OTP.';
          });
          _showError(_errorMessage!);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('resendOtp codeSent');
          if (!mounted) return;
          setState(() {
            _activeVerificationId = verificationId;
            _resendToken = resendToken;
          });
          _startResendTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP resent successfully')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('resendOtp codeAutoRetrievalTimeout');
          if (!mounted) return;
          setState(() {
            _activeVerificationId = verificationId;
          });
        },
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('resendOtp FirebaseAuthException: ${e.code} ${e.message}');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message ?? 'Failed to resend OTP.';
      });
      _showError(_errorMessage!);
    } catch (e) {
      debugPrint('resendOtp error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to resend OTP. Please try again.';
      });
      _showError(_errorMessage!);
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.largePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'OTP Verification',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.debugBypass
                    ? 'Simulator mode: enter test OTP 123456 for ${widget.phoneNumber}'
                    : 'Enter the 6-digit OTP sent to ${widget.phoneNumber}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'OTP',
                  hintText: 'Enter 6 digit OTP',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                  errorText: _errorMessage,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(AppSizes.largeButtonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: (_secondsUntilResend == 0 && !_isResending && !_isLoading)
                    ? _resendOtp
                    : null,
                child: _isResending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _secondsUntilResend > 0
                            ? 'Resend OTP in ${_secondsUntilResend}s'
                            : 'Resend OTP',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
