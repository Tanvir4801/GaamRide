import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/booking_request_screen.dart';
import '../screens/tracking_screen.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _rideRequestsChannel =
      AndroidNotificationChannel(
    'ride_requests',
    'Ride Requests',
    description: 'Ride request notifications for Saathi',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationChannel _rideStatusChannel =
      AndroidNotificationChannel(
    'ride_status',
    'Ride Status',
    description: 'Ride acceptance and rejection updates for customers',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  static GlobalKey<NavigatorState>? _navigatorKey;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static bool _isInitialized = false;
  static String? _currentToken;

  static String? get currentToken => _currentToken;

  static void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iOSSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(_rideRequestsChannel);
    await androidImplementation?.createNotificationChannel(_rideStatusChannel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(showRemoteMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleRemoteMessage);

    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _currentToken = token;
      await syncCurrentUserToken(token: token);
    });

    _currentToken = await FirebaseMessaging.instance.getToken();
    _isInitialized = true;
  }

  static Future<void> initializeForBackground() async {
    if (_isInitialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iOSSettings,
      ),
    );

    _isInitialized = true;
  }

  static Future<void> handleInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      handleRemoteMessage(message);
    });
  }

  static Future<void> syncCurrentUserToken({String? token}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final resolvedToken = token ?? await FirebaseMessaging.instance.getToken();
    _currentToken = resolvedToken;
    if (resolvedToken == null || resolvedToken.isEmpty) {
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    batch.set(
      firestore.collection('users').doc(user.uid),
      {
        'uid': user.uid,
        'fcmToken': resolvedToken,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      firestore.collection('saathi').doc(user.uid),
      {
        'uid': user.uid,
        'fcmToken': resolvedToken,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
    final data = message.data;
    final target = data['target']?.toString();
    final title = message.notification?.title ?? data['title']?.toString() ?? 'GaamRide';
    final body = message.notification?.body ?? data['body']?.toString() ?? '';

    if (target == 'booking_request') {
      await showRideRequestNotification(
        bookingId: data['bookingId']?.toString() ?? '',
        fromVillage: data['fromVillage']?.toString() ?? '',
        toVillage: data['toVillage']?.toString() ?? '',
        type: data['type']?.toString() ?? 'ride',
        distanceKm: data['distanceKm']?.toString(),
      );
      return;
    }

    if (target == 'booking_status') {
      await showRideStatusNotification(
        status: data['status']?.toString() ?? 'updated',
        saathiName: data['saathiName']?.toString() ?? 'Gaam Saathi',
      );
      return;
    }

    await showNotification(title: title, body: body, payload: jsonEncode(data));
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'ride_status',
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId == _rideRequestsChannel.id
            ? _rideRequestsChannel.name
            : _rideStatusChannel.name,
        channelDescription: channelId == _rideRequestsChannel.id
            ? _rideRequestsChannel.description
            : _rideStatusChannel.description,
        importance: channelId == _rideRequestsChannel.id
            ? Importance.high
            : Importance.defaultImportance,
        priority: channelId == _rideRequestsChannel.id
            ? Priority.high
            : Priority.defaultPriority,
        playSound: true,
        icon: '@drawable/ic_notification',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static Future<void> showRideRequestNotification({
    required String bookingId,
    required String fromVillage,
    required String toVillage,
    required String type,
    String? distanceKm,
  }) async {
    final body = '$fromVillage → $toVillage ($type)';
    final payload = jsonEncode({
      'target': 'booking_request',
      'bookingId': bookingId,
      'fromVillage': fromVillage,
      'toVillage': toVillage,
      'type': type,
      if (distanceKm != null) 'distanceKm': distanceKm,
    });

    await showNotification(
      title: 'New Ride Request!',
      body: body,
      payload: payload,
      channelId: _rideRequestsChannel.id,
    );
  }

  static Future<void> showRideStatusNotification({
    required String status,
    required String saathiName,
  }) async {
    final isAccepted = status.toLowerCase() == 'accepted';
    final title = isAccepted ? 'Saathi is coming!' : 'Ride not available';
    final body = isAccepted
        ? '$saathiName accepted your ride'
        : 'Saathi rejected. Finding another...';

    await showNotification(
      title: title,
      body: body,
      payload: jsonEncode({
        'target': 'booking_status',
        'status': status,
        'saathiName': saathiName,
      }),
      channelId: _rideStatusChannel.id,
    );
  }

  static Future<void> handleRemoteMessage(RemoteMessage message) async {
    final data = message.data;
    final target = data['target']?.toString();

    if (target == 'booking_request') {
      _openBookingRequest(data);
      return;
    }

    if (target == 'booking_status') {
      final status = data['status']?.toString().toLowerCase();
      if (status == 'accepted') {
        _openTrackingScreen(data);
      } else if (status == 'rejected') {
        _showRejectedDialog();
      }
    }
  }

  static void _openBookingRequest(Map<String, dynamic> data) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BookingRequestScreen(
          bookingId: data['bookingId']?.toString() ?? '',
          fromVillage: data['fromVillage']?.toString() ?? '',
          toVillage: data['toVillage']?.toString() ?? '',
          type: data['type']?.toString() ?? 'ride',
          distanceKm: data['distanceKm'] == null
              ? null
              : double.tryParse(data['distanceKm'].toString()),
        ),
      ),
    );
  }

  static void _openTrackingScreen(Map<String, dynamic> data) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => TrackingScreen(
          bookingId: data['bookingId']?.toString() ?? '',
          saathiId: data['saathiId']?.toString(),
          saathiName: data['saathiName']?.toString(),
        ),
      ),
    );
  }

  static void _showRejectedDialog() {
    final context = _navigatorKey?.currentState?.overlay?.context;
    if (context == null) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ride not available'),
          content: const Text('Finding another Saathi...'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final target = data['target']?.toString();
      if (target == 'booking_request') {
        _openBookingRequest(data);
      } else if (target == 'booking_status') {
        final status = data['status']?.toString().toLowerCase();
        if (status == 'accepted') {
          _openTrackingScreen(data);
        } else if (status == 'rejected') {
          _showRejectedDialog();
        }
      }
    } catch (_) {
      return;
    }
  }
}