import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'GaamRide';
  static const String saathiCollection = 'saathi';
  static const String googleMapsApiKey = 'AIzaSyAQy_Ong62n2ujYi2EwOe6mwe3_eK4erXc';
  
  static const List<String> vehicleTypes = [
    'Bike',
    'Auto',
    'Tempo',
    'Truck',
  ];

  static const List<String> locationOptions = [
    'Highway',
    'Bus Stand',
    'Market',
    'Village Center',
  ];
}

class AppColors {
  static const Color primary = Color(0xFF2E7D32);
  static const Color secondary = Color(0xFFFFA000);
  static const Color background = Color(0xFFF8F9FA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
}

class AppSizes {
  static const double largeButtonHeight = 56;
  static const double buttonRadius = 10;
  static const double defaultPadding = 16;
  static const double smallPadding = 8;
  static const double largePadding = 24;
}

class ValidationText {
  static const String emptyPhone = 'Please enter a phone number';
  static const String invalidPhone = 'Phone number must be at least 10 digits';
  static const String emptyOtp = 'Please enter OTP';
  static const String invalidOtp = 'OTP must be 6 digits';
  static const String emptyName = 'Please enter your name';
  static const String emptyVillage = 'Please select a village';
  static const String emptyVehicleType = 'Please select a vehicle type';
}

