import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'main_shell.dart';
import 'home_screen.dart';
import 'role_selection_screen.dart';
import 'saathi_dashboard.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  late final Future<Widget> _targetScreenFuture = _resolveTargetScreen();

  Widget _buildSplashLoading() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.largePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.directions_car_filled,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Checking your account...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Widget> _resolveTargetScreen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return const HomeScreen();
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        return const RoleSelectionScreen();
      }

      final role = (doc.data()?['role'] ?? '').toString();
      if (role == 'saathi') {
        return GaamSaathiDashboard(phone: user.phoneNumber ?? user.uid);
      }

      if (role == 'customer') {
        return const MainShell();
      }

      return const RoleSelectionScreen();
    } on FirebaseException {
      return const HomeScreen();
    } catch (_) {
      return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _targetScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildSplashLoading();
        }

        if (snapshot.hasData) {
          return snapshot.data!;
        }

        return const HomeScreen();
      },
    );
  }
}
