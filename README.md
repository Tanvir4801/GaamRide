# GaamRide

A Flutter app connecting village-based transport providers (Gaam Saathi) with customers.

## Features

### For Customers
- Search and find available Gaam Saathi (transport providers)
- Filter by location and destination
- Call or WhatsApp Saathi directly
- Rate and review drivers

### For Gaam Saathi (Drivers)
- **Phone OTP Authentication** - Secure login with phone number
- **Google Sign-In Authentication** - Quick login with Google account
- Complete profile with name, vehicle type, and village
- Manage availability status (Online/Offline toggle)
- Receive and respond to customer requests
- View ratings and feedback

## Authentication Methods

### 1. Phone OTP (SMS)
- Traditional OTP-based login
- Works without internet for initial authentication
- Secure Firebase-backed authentication

### 2. Google Sign-In (NEW)
- One-tap sign-in with Google account
- Auto-fills user name from Google profile
- Seamless cross-device authentication
- See [Google Sign-In Setup Guide](GOOGLE_SIGNIN_SETUP.md) for setup

## Getting Started

### Prerequisites
- Flutter SDK 3.3.0 or higher
- Android SDK (for Android build)
- Xcode (for iOS build)
- Firebase project configured
- Google Cloud project (for Google Sign-In)

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd gaamride
```

2. Install dependencies
```bash
flutter pub get
```

3. Configure Firebase
- Download `google-services.json` (Android) from Firebase Console
- Download `GoogleService-Info.plist` (iOS) from Firebase Console
- Place in appropriate directories (already configured)

4. Configure Google Sign-In
- Follow [GOOGLE_SIGNIN_SETUP.md](GOOGLE_SIGNIN_SETUP.md)

5. Run the app
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   └── driver_model.dart     # GaamSaathi model
├── screens/                  # UI Screens
│   ├── home_screen.dart                      # Role selection
│   ├── gaam_saathi_login_screen.dart         # Saathi login (OTP + Google)
│   ├── gaam_saathi_register_screen.dart      # Saathi profile setup
│   ├── gaam_saathi_dashboard.dart            # Saathi dashboard
│   ├── customer_home_screen.dart             # Customer search
│   ├── otp_verification_screen.dart          # OTP entry screen
│   └── auth_gate_screen.dart                 # Initial auth check
├── services/                 # Business logic
│   ├── auth_service.dart             # Phone OTP authentication
│   ├── google_auth_service.dart      # Google Sign-In (NEW)
│   ├── firestore_service.dart        # Firestore operations
│   └── user_service.dart             # User management
├── utils/
│   └── constants.dart        # App-wide constants & themes
└── widgets/                  # Reusable widgets
```

## Firebase Firestore Structure

```
saathi/
├── {phone_number}
    ├── name: String
    ├── phone: String
    ├── email: String (for Google Sign-In users)
    ├── village: String
    ├── vehicleType: String
    ├── isAvailable: Boolean
    ├── rating: Number
    └── verified: Boolean
```

## Authentication Flow

### Phone OTP Flow
1. User enters phone number
2. Firebase sends OTP
3. User enters OTP
4. Phone authenticated in Firebase
5. App checks Firestore record
6. If exists → Dashboard
7. If new → Registration screen

### Google Sign-In Flow
1. User clicks "Continue with Google"
2. Google authentication dialog appears
3. User signs in with Google account
4. Firebase authenticates with Google token
5. App extracts name/email from Google profile
6. Check Firestore for existing record
7. If exists → Dashboard with existing data
8. If new → Registration screen with pre-filled name

## Dashboard Features

- **Profile Display**: Name, vehicle type, village, rating
- **Availability Toggle**: Switch between Online/Offline status
- **Verification Status**: Shows if profile is verified
- **Logout**: Secure sign-out with confirmation

## Error Handling

- Network errors with retry options
- Firebase authentication errors
- Firestore query errors
- Graceful degradation for simulator testing
- User-friendly error messages via snackbars

## Testing

### Test Accounts
- **For OTP**: +91 7621984915 (with code 123456 on simulator)
- **For Google**: Any Gmail account (requires Firebase configuration)

### Debug Mode
- Direct login with phone 9876543210 (simulator only)
- Detailed logging in debug console
- Firebase Emulator Suite compatible

## Browser & Platform Support

- ✅ Android 5.0+
- ✅ iOS 12.0+
- ✅ Linux
- ✅ macOS
- ✅ Windows

## Dependencies

- **firebase_core**: Firebase initialization
- **firebase_auth**: Phone & cryptographic authentication
- **google_sign_in**: Google Sign-In integration
- **cloud_firestore**: User data storage
- **google_maps_flutter**: Location display
- **geolocator**: Device location
- **geocoding**: Address conversion
- **url_launcher**: Phone/WhatsApp integration

## Development

### Code Style
- Null-safe Dart code
- Material Design 3
- Responsive UI for various screen sizes

### Running Tests
```bash
flutter test
```

### Building Release
```bash
# Android
flutter build apk

# iOS
flutter build ios

# Web
flutter build web
```

## Configuration Files

- `pubspec.yaml` - Dependencies and project metadata
- `firebase.json` - Firebase project configuration
- `analysis_options.yaml` - Dart analysis rules
- `android/app/google-services.json` - Android Firebase config
- `ios/GoogleService-Info.plist` - iOS Firebase config

## Environment Variables

No environment variables required. All configuration is through Firebase Console.

## Troubleshooting

### Google Sign-In Issues
See [GOOGLE_SIGNIN_SETUP.md](GOOGLE_SIGNIN_SETUP.md) for detailed troubleshooting

### Firebase Issues
- Check Firebase Console for quota limits
- Verify Firestore security rules allow read/write
- Check network connectivity

### Build Issues
```bash
# Clean build
flutter clean
flutter pub get
flutter run
```

## Security

- ✅ All credentials handled via Firebase (no app storage)
- ✅ Secure OAuth 2.0 token exchange
- ✅ Firestore security rules (configure in console)
- ✅ No sensitive data in logs
- ✅ Encrypted data transmission

## Performance

- ~3-4MB APK size (base)
- ~100MB download with Flutter engine
- Fast initialization with lazy loading
- Optimized Firestore queries

## Future Enhancements

- Real-time chat between customers and Saathi
- In-app payment integration
- Push notifications
- Advanced booking system
- Rating and review system
- Referral program

## License

Private project. See LICENSE file for details.

## Support

For issues or questions:
1. Check [GOOGLE_SIGNIN_SETUP.md](GOOGLE_SIGNIN_SETUP.md) for authentication help
2. Review Firebase Console logs
3. Check Flutter doctor output: `flutter doctor -v`
4. Enable debug logging: `flutter run -v`

## Contributors

- GaamRide Team

## Acknowledgments

- Flutter and Dart teams
- Firebase by Google
- Google Sign-In library

