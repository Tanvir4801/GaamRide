import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate_screen.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/village_service.dart';
import 'utils/constants.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initializeForBackground();
  await NotificationService.showRemoteMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // FEATURE: Initialize villages in Firestore (debug mode only)
  await VillageService.initializeVillages();

  // DEBUG: Create test Saathis for development (debug mode only)
  await LocationService.createTestSaathisForDebug();

  runApp(const GaamRideApp());
}

class GaamRideApp extends StatefulWidget {
  const GaamRideApp({super.key});

  @override
  State<GaamRideApp> createState() => _GaamRideAppState();
}

class _GaamRideAppState extends State<GaamRideApp> {
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    NotificationService.setNavigatorKey(appNavigatorKey);

    if (Firebase.apps.isNotEmpty) {
      _initializeNotifications();

      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          NotificationService.syncCurrentUserToken();
        }
      });
    }
  }

  Future<void> _initializeNotifications() async {
    await NotificationService.initialize();
    await NotificationService.handleInitialMessage();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.largeButtonHeight),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: const AuthGateScreen(),
    );
  }
}
