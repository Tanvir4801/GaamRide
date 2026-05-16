import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/constants.dart';
import 'main_shell.dart';
import 'home_screen.dart' as home;

class GaamSaathiRegisterScreen extends StatefulWidget {
  const GaamSaathiRegisterScreen({
    this.phone,
    this.googleName,
    this.googleEmail,
    super.key,
  });

  final String? phone;
  final String? googleName;
  final String? googleEmail;

  @override
  State<GaamSaathiRegisterScreen> createState() =>
      _GaamSaathiRegisterScreenState();
}

class _GaamSaathiRegisterScreenState extends State<GaamSaathiRegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _villageController = TextEditingController();

  String? _vehicleType;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.googleName != null && widget.googleName!.isNotEmpty) {
      _nameController.text = widget.googleName!;
    }
    if (widget.phone != null && widget.phone!.isNotEmpty) {
      _phoneController.text = widget.phone!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final village = _villageController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorMessage = ValidationText.emptyName;
      });
      return false;
    }

    if (phone.isEmpty) {
      setState(() {
        _errorMessage = ValidationText.emptyPhone;
      });
      return false;
    }

    if (phone.length < 10) {
      setState(() {
        _errorMessage = ValidationText.invalidPhone;
      });
      return false;
    }

    if (village.isEmpty) {
      setState(() {
        _errorMessage = ValidationText.emptyVillage;
      });
      return false;
    }

    if (_vehicleType == null) {
      setState(() {
        _errorMessage = ValidationText.emptyVehicleType;
      });
      return false;
    }

    setState(() {
      _errorMessage = null;
    });
    return true;
  }

  Future<void> _registerSaathi() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      final phone = _phoneController.text.trim();
      final normalizedPhone = phone.startsWith('+91') ? phone : '+91$phone';

      await FirebaseFirestore.instance.collection('saathi').doc(normalizedPhone).set({
        'uid': authUser?.uid,
        'name': _nameController.text.trim(),
        'phone': normalizedPhone,
        'village': _villageController.text.trim(),
        'vehicleType': _vehicleType!,
        'isAvailable': true,
        'rating': 5.0,
        'verified': false,
        'currentLocation': 'Highway',
        'vehicleUpdatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (authUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(authUser.uid).set(
          {
            'uid': authUser.uid,
            'phone': normalizedPhone,
            'displayName': _nameController.text.trim(),
            'role': 'saathi',
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful!'),
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
            builder: (_) => const MainShell(),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message ?? 'Registration failed. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Registration failed. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goBack() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const home.HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Gaam Saathi'),
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.largePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Complete Your Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Fill in all details to get started',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(AppSizes.defaultPadding),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(26),
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                    ),
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  hintText: 'Enter your full name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '10 digit mobile number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _villageController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Village Name',
                  hintText: 'Enter your village name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _vehicleType,
                decoration: InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                items: AppConstants.vehicleTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _vehicleType = value;
                          _errorMessage = null;
                        });
                      },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize:
                      const Size.fromHeight(AppSizes.largeButtonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                onPressed: _isLoading ? null : _registerSaathi,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Register as Gaam Saathi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(AppSizes.largeButtonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                  side: const BorderSide(color: AppColors.primary),
                ),
                onPressed: _isLoading ? null : _goBack,
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
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
