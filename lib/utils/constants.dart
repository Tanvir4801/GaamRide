import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'GaamRide';
  static const String saathiCollection = 'saathis';
  static const String haulVehicleCollection = 'haul_vehicles';
  static const String bookingsCollection = 'bookings';
  static const String driverRequestsCollection = 'driver_requests';
  static const String usersCollection = 'users';
  static const String googleMapsApiKey = 'AIzaSyAQy_Ong62n2ujYi2EwOe6mwe3_eK4erXc';

  static const List<String> vehicleTypes = ['Bike', 'Auto', 'Tempo', 'Truck'];

  static const List<String> locationOptions = [
    'Highway',
    'Bus Stand',
    'Market',
    'Village Center',
  ];

  static const String outOfServiceZoneMessage =
      'GaamRide ફક્ત Mahuva તાલુકામાં ઉપલબ્ધ છે\nGaamRide is only available in Mahuva taluka';
  static const String noInternetMessage =
      'ઇન્ટરનેટ કનેક્શન નથી / No internet connection';
  static const String enableLocationMessage =
      'લોકેશન ચાલુ કરો / Please enable location';
}

class AppColors {
  // GaamRide (green)
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primarySurface = Color(0xFFE8F5E9);

  // GaamHaul (orange)
  static const Color haul = Color(0xFFE65100);
  static const Color haulLight = Color(0xFFFF7043);
  static const Color haulSurface = Color(0xFFFBE9E7);

  // Common
  static const Color secondary = Color(0xFFFFA000);
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);
}

class AppSizes {
  static const double largeButtonHeight = 56;
  static const double buttonRadius = 12;
  static const double cardRadius = 16;
  static const double defaultPadding = 16;
  static const double smallPadding = 8;
  static const double largePadding = 24;
}

class RideStatus {
  static const String searching = 'pending';
  static const String accepted = 'accepted';
  static const String arriving = 'arriving';
  static const String started = 'started';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String rejected = 'rejected';
}

class ValidationText {
  static const String emptyPhone = 'ફોન નંબર દાખલ કરો / Please enter a phone number';
  static const String invalidPhone =
      'ફોન નંબર 10 અંકનો હોવો જોઈએ / Phone number must be at least 10 digits';
  static const String emptyOtp = 'OTP દાખલ કરો / Please enter OTP';
  static const String invalidOtp = 'OTP 6 અંકનો હોવો જોઈએ / OTP must be 6 digits';
  static const String emptyName = 'નામ દાખલ કરો / Please enter your name';
  static const String emptyVillage = 'ગામ પસંદ કરો / Please select a village';
  static const String emptyVehicleType =
      'વાહન પ્રકાર પસંદ કરો / Please select a vehicle type';
}
