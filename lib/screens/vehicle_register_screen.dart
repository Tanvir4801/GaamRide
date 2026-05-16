import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../utils/constants.dart';

class VehicleRegisterScreen extends StatefulWidget {
  const VehicleRegisterScreen({super.key});

  @override
  State<VehicleRegisterScreen> createState() => _VehicleRegisterScreenState();
}

class _VehicleRegisterScreenState extends State<VehicleRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _rateController = TextEditingController();
  final _vehicleNumberController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingProfile = true;

  String? _vehicleType;
  String? _capacity;
  String? _homeVillage;

  static const Color _orange = Color(0xFFE65100);

  static const Map<String, String> _vehicleTypeOptions = {
    'mini_tempo': 'Mini Tempo',
    'pickup': 'Pickup Truck',
    'tractor': 'Tractor',
  };

  static const List<String> _capacityOptions = [
    '250kg',
    '500kg',
    '1000kg',
    '2000kg+',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _phoneController.dispose();
    _rateController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isLoadingProfile = false;
        });
        return;
      }

      _ownerNameController.text = user.displayName ?? '';
      _phoneController.text = _normalizePhone(user.phoneNumber ?? '');

      final doc = await FirebaseFirestore.instance
          .collection('haul_vehicles')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        _ownerNameController.text =
            (data['ownerName']?.toString().trim().isNotEmpty ?? false)
                ? data['ownerName'].toString().trim()
                : _ownerNameController.text;
        _phoneController.text =
            (data['phone']?.toString().trim().isNotEmpty ?? false)
                ? _normalizePhone(data['phone'].toString())
                : _phoneController.text;
        _vehicleType = data['vehicleType']?.toString();
        _capacity = data['capacity']?.toString();
        _homeVillage = data['villageName']?.toString();
        _rateController.text = (data['ratePerHour'] ?? '').toString();
        _vehicleNumberController.text =
            (data['vehicleNumber'] ?? '').toString().trim();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('પ્રોફાઇલ વાંચવામાં નિષ્ફળ / Failed to load profile'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  String _normalizePhone(String raw) {
    final onlyDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.length > 10) {
      return onlyDigits.substring(onlyDigits.length - 10);
    }
    return onlyDigits;
  }

  Future<GeoFirePoint?> _currentGeoPoint() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return GeoFirePoint(GeoPoint(position.latitude, position.longitude));
  }

  Future<void> _saveVehicle() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_vehicleType == null || _capacity == null || _homeVillage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('બધી જરૂરી માહિતી भरो / Fill all required details'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('પહેલાં લૉગિન કરો / Please login first'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final geoPoint = await _currentGeoPoint();
      final fallbackVillage = LocationService.approvedVillages.firstWhere(
        (v) => v.name == _homeVillage,
        orElse: () => LocationService.approvedVillages.first,
      );

      final resolvedPoint = geoPoint ??
          GeoFirePoint(GeoPoint(fallbackVillage.lat, fallbackVillage.lng));

      await FirebaseFirestore.instance
          .collection('haul_vehicles')
          .doc(user.uid)
          .set(
        {
          'ownerId': user.uid,
          'ownerName': _ownerNameController.text.trim(),
          'phone': _normalizePhone(_phoneController.text.trim()),
          'vehicleType': _vehicleType,
          'capacity': _capacity,
          'ratePerHour': int.parse(_rateController.text.trim()),
          'vehicleNumber': _vehicleNumberController.text.trim(),
          'villageName': _homeVillage,
          'position': resolvedPoint.data,
          'isAvailable': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('તમારું વાહન નોંધાઈ ગયું! / Vehicle registered!'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('સેવ કરવામાં નિષ્ફળ / Failed to save vehicle details'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final villages = LocationService.approvedVillages.map((v) => v.name).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: const Text('વાહન નોંધો / Register Vehicle'),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.defaultPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _ownerNameController,
                      decoration: const InputDecoration(
                        labelText: 'માલિકનું નામ / Owner name',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'નામ જરૂરી છે / Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'ફોન નંબર / Phone number',
                      ),
                      validator: (value) {
                        final phone = _normalizePhone(value ?? '');
                        if (phone.length < 10) {
                          return 'માન્ય ફોન નંબર નાખો / Enter valid phone';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _vehicleType,
                      decoration: const InputDecoration(
                        labelText: 'વાહન પ્રકાર / Vehicle type',
                      ),
                      items: _vehicleTypeOptions.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _vehicleType = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _capacity,
                      decoration: const InputDecoration(
                        labelText: 'ક્ષમતા / Capacity',
                      ),
                      items: _capacityOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _capacity = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'કલાક દીઠ ભાડું / Rate per hour',
                        hintText: 'સામાન્ય ભાડું દાખલ કરો (ઉદાહરણ: 600)',
                      ),
                      validator: (value) {
                        final rate = int.tryParse((value ?? '').trim());
                        if (rate == null || rate <= 0) {
                          return 'માન્ય ભાડું દાખલ કરો / Enter valid rate';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _vehicleNumberController,
                      decoration: const InputDecoration(
                        labelText: 'વાહન નંબર (વૈકલ્પિક) / Vehicle number (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _homeVillage,
                      decoration: const InputDecoration(
                        labelText: 'ગામ / Home village',
                      ),
                      items: villages
                          .map(
                            (name) => DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _homeVillage = value),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveVehicle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('વાહન નોંધો / Register Vehicle'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}