# Google Sign-In Setup Guide for GaamRide

This guide walks through setting up Google Sign-In authentication for your Flutter app with Firebase.

## Prerequisites
- Firebase project created
- Firebase initialized in Flutter app (already done ✓)
- google_sign_in package added (already done ✓)

## Firebase Configuration

### 1. Enable Google Sign-In Provider in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Authentication** > **Sign-in method**
4. Click on **Google** provider
5. Enable it by toggling the switch
6. Add a **Project Support Email** (appears in consent screen)
7. Click **Save**

### 2. Configure OAuth Consent Screen (if needed)

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Navigate to **APIs & Services** > **OAuth consent screen**
4. Fill in the application details:
   - App name: "GaamRide"
   - User support email: your-email@example.com
   - Developer contact: your-email@example.com
5. Click **Save and Continue**

### 3. iOS Configuration

1. In your Xcode project:
   - Open `ios/Runner.xcodeproj`
   - Select Runner target
   - Go to **Signin & Capabilities**
   - Add **Sign In with Apple** (if you want that too)

2. Update `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <!-- Add your reversed Google Client ID -->
         <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
       </array>
     </dict>
   </array>
   ```

3. Get your Google Client ID:
   - Go to Firebase Console > Project Settings > Service Accounts
   - Look for OAuth 2.0 client IDs

### 4. Android Configuration

The Firebase integration should handle this automatically. Verify in `android/app/google-services.json`.

### 5. Web Configuration (if applicable)

1. In Firebase Console, add your web domain to authorized JavaScript origins
2. Go to **Authentication** > **Settings**
3. Add your web domain under "Authorized domains"

## Implementation Details

### Files Modified/Created

1. **pubspec.yaml**
   - Added `google_sign_in: ^6.2.1`

2. **lib/services/google_auth_service.dart** (New)
   - Handles Google Sign-In authentication
   - Returns user credentials
   - Extracts user information (name, email, phone)

3. **lib/screens/gaam_saathi_login_screen.dart**
   - Added "Continue with Google" button
   - Implements Google Sign-In flow
   - Integrates with Firestore user check

4. **lib/screens/gaam_saathi_register_screen.dart**
   - Accepts Google user data
   - Pre-fills name field from Google profile

## Firestore Structure for Google Sign-In Users

When a user signs in with Google, their data is stored in Firestore with this structure:

```
Collection: saathi
Document ID: {email_or_phone_or_uid}
Fields:
  - name: string (pre-filled from Google profile)
  - phone: string (email if phone not provided)
  - village: string (user enters during registration)
  - vehicleType: string
  - isAvailable: boolean
  - rating: number (default 5.0)
  - verified: boolean (default false)
```

## Error Handling

The Google Sign-In implementation includes:

- ✓ User cancellation handling
- ✓ Firebase authentication errors
- ✓ Network error handling
- ✓ Loading states with UI feedback
- ✓ Snackbar error messages
- ✓ Duplicate user prevention in Firestore

## Flow Diagram

```
Login Screen
    ↓
Click "Continue with Google"
    ↓
Google Sign-In Dialog
    ↓
User Authenticates
    ↓
Get Firebase Token
    ↓
Check Firestore (saathi collection)
    ↓
    ├─ User Exists → Dashboard
    └─ New User → Registration Screen (pre-filled with name)
                         ↓
                      Enter Details
                         ↓
                    Save to Firestore
                         ↓
                      Dashboard
```

## Testing

### Local Testing
1. Run `flutter pub get` to install packages
2. Use iOS Simulator or Android Emulator
3. Click "Continue with Google"
4. Sign in with a test Google account

### Production Testing
1. Build release APK/IPA
2. Test on physical device
3. Monitor Firebase Analytics for sign-in events

## Common Issues & Solutions

### Issue: "Google Sign-In failed"
**Solution:** 
- Verify Google Cloud project OAuth consent screen is configured
- Check Firebase Console has Google provider enabled
- Ensure correct iOS reversed client ID in Info.plist

### Issue: "User cancelled Google Sign-In"
**Solution:** This is expected behavior - user closed the sign-in dialog

### Issue: Email not appearing in user profile
**Solution:** 
- User's Google account may have privacy settings
- App can still sign in using UID as identifier
- Firestore lookup will use email/phone/UID in priority order

### Issue: Phone number not available from Google
**Solution:**
- Google doesn't always provide phone numbers
- App uses email as fallback identifier
- User enters phone during registration if needed

## Security Notes

✓ Uses official Firebase Authentication
✓ No credentials stored in app
✓ Secure token exchange with Firebase backends
✓ Uses OAuth 2.0 best practices
✓ Phone numbers stored securely in Firestore
✓ No sensitive data logged in debug mode

## Next Steps

1. Run `flutter pub get` to fetch google_sign_in package
2. Follow the Firebase configuration steps above
3. Test Google Sign-In on simulator/device
4. Monitor Firebase Console for authentication events
