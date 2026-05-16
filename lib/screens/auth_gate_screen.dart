import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'home_screen.dart';
import 'main_shell.dart';
import 'role_selection_screen.dart';
import 'saathi_dashboard.dart';
import 'vehicle_owner_dashboard.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen>
    with SingleTickerProviderStateMixin {
  late final Future<Widget> _targetFuture = _resolveTargetScreen();
  late final AnimationController _logoController;
  late final Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<Widget> _resolveTargetScreen() async {
    // Brief pause for splash feel
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return const HomeScreen();

      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (!doc.exists) return const RoleSelectionScreen();

      final role = (doc.data()?['role'] ?? '').toString();

      switch (role) {
        case 'saathi':
          return GaamSaathiDashboard(
            phone: user.phoneNumber ?? user.uid,
          );
        case 'haul_saathi':
          return VehicleOwnerDashboard(vehicleDocId: user.uid);
        case 'customer':
          return const MainShell();
        case 'both':
          // Has both saathi and customer roles → show main shell with both tabs
          return const MainShell();
        default:
          return const RoleSelectionScreen();
      }
    } on FirebaseException {
      return const HomeScreen();
    } catch (_) {
      return const HomeScreen();
    }
  }

  Widget _buildSplash() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _logoAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_bike_rounded,
                      color: AppColors.primary,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'GaamRide',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ગામડાઓ જોડવા',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'Connecting Villages',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _targetFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildSplash();
        }
        return snapshot.data ?? const HomeScreen();
      },
    );
  }
}
