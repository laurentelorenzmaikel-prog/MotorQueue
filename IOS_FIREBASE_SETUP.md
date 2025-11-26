# iOS Firebase Configuration Guide

## ⚠️ CRITICAL: iOS Firebase Not Configured

Your iOS app **CANNOT connect to Firebase** because the `GoogleService-Info.plist` file is missing.

## Steps to Configure iOS Firebase

### 1. Get GoogleService-Info.plist from Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **lorenz-app** (or **lorenz-motorcycle-servic-47ae6** depending on which project you're using)
3. Click the **⚙️ Settings** icon → **Project settings**
4. Scroll down to **Your apps** section
5. Find the iOS app or click **Add app** → **iOS**

### 2. Register iOS App (if not already registered)

If you don't have an iOS app registered:

1. Click **Add app** → **iOS**
2. Enter iOS bundle ID: `com.example.lorenz-app` (or your actual bundle ID)
   - ⚠️ **Important**: This must match your Xcode project's bundle identifier
3. Enter app nickname: `Lorenz Motorcycle Service iOS`
4. Enter App Store ID: (optional, leave blank for now)
5. Click **Register app**

### 3. Download GoogleService-Info.plist

1. Click **Download GoogleService-Info.plist**
2. Save the file to your computer

### 4. Add GoogleService-Info.plist to Xcode Project

**Method 1: Using Xcode (Recommended)**

1. Open Xcode project:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode, right-click on the **Runner** folder in the Project Navigator
3. Select **Add Files to "Runner"...**
4. Navigate to where you saved `GoogleService-Info.plist`
5. **IMPORTANT**: Make sure to check:
   - ✅ **Copy items if needed**
   - ✅ **Add to targets: Runner**
6. Click **Add**

**Method 2: Manual Copy**

1. Copy `GoogleService-Info.plist` to:
   ```
   lorenz_app/ios/Runner/GoogleService-Info.plist
   ```

2. Open `ios/Runner.xcworkspace` in Xcode

3. Verify the file appears in the Runner folder in Project Navigator

4. Select the file and ensure in the File Inspector (right panel):
   - Target Membership → Runner is checked

### 5. Verify Configuration

1. Open `ios/Runner.xcworkspace` in Xcode
2. Check that `GoogleService-Info.plist` is visible in the Runner folder
3. Build the project (Cmd+B) to ensure no errors

### 6. Update Bundle Identifier (if needed)

If you change the bundle identifier from `com.example.lorenz-app`:

1. In Xcode, select **Runner** project
2. Select **Runner** target
3. Go to **General** tab
4. Update **Bundle Identifier** to match your Firebase iOS app bundle ID

### 7. Test Firebase Connection

Run the app on iOS simulator or device:

```bash
flutter run -d ios
```

Check the console output for Firebase initialization messages. You should see:
```
[firebase_core] Successfully configured Firebase!
```

## Troubleshooting

### Error: "Could not locate configuration file"

**Solution**: Make sure `GoogleService-Info.plist` is:
- In the `ios/Runner/` directory
- Added to the Xcode project with "Copy items if needed" checked
- Has Runner as a target

### Error: "Bundle identifier mismatch"

**Solution**: The bundle ID in `GoogleService-Info.plist` must match:
- Your Xcode project's bundle identifier
- The bundle ID registered in Firebase Console

To check/fix:
1. Open `GoogleService-Info.plist` in a text editor
2. Find `BUNDLE_ID` key
3. Ensure it matches your Xcode bundle identifier

### Error: "Firebase not initialized"

**Solution**:
1. Clean build folder: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Rebuild: `flutter run -d ios`

## Firebase Services Configuration

After adding `GoogleService-Info.plist`, ensure these Firebase services are enabled:

### Firebase Authentication
- ✅ Enable Email/Password authentication
- ✅ Enable Google Sign-In (requires additional setup)

### Google Sign-In Additional Setup

1. Add URL scheme to `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <!-- Replace with REVERSED_CLIENT_ID from GoogleService-Info.plist -->
         <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```

2. Get REVERSED_CLIENT_ID from `GoogleService-Info.plist`
3. Replace `YOUR_CLIENT_ID` with actual value

### Firestore, Storage, Analytics
- ✅ Automatically configured via `GoogleService-Info.plist`

## Current Status

- ❌ **iOS Firebase NOT configured** - Missing `GoogleService-Info.plist`
- ✅ **Android Firebase configured** - `google-services.json` present
- ✅ **Web Firebase configured** - Using `firebase_options.dart`

## Next Steps

1. ✅ Download `GoogleService-Info.plist` from Firebase Console
2. ✅ Add file to `ios/Runner/` directory
3. ✅ Open in Xcode and verify target membership
4. ✅ Test iOS build
5. ✅ Configure Google Sign-In URL scheme (if using Google auth)

## References

- [FlutterFire iOS Setup](https://firebase.google.com/docs/flutter/setup?platform=ios)
- [Firebase Console](https://console.firebase.google.com/)
- [Add Firebase to iOS](https://firebase.google.com/docs/ios/setup)

---

**⚠️ WARNING**: Do not commit `GoogleService-Info.plist` to public repositories as it contains API keys. The file is already in `.gitignore` for security.
