# Android Package Name Change Guide

## ⚠️ CRITICAL: Cannot Publish to Play Store with com.example Package

Your Android app currently uses `com.example.lorenz_app` which is **NOT allowed** on Google Play Store.

## Why This Must Be Changed

- ❌ **com.example** is a reserved namespace
- ❌ Cannot publish to Google Play Store
- ❌ Looks unprofessional
- ❌ May cause conflicts with other apps

## Recommended Package Names

Choose a package name that follows this format: `com.yourcompany.appname`

**Examples:**
- ✅ `com.lorenz.motorcycleservice`
- ✅ `com.lorenzmotorcycles.app`
- ✅ `ph.lorenz.service` (if Philippines-based)
- ✅ `io.lorenz.app`

**Requirements:**
- Must contain at least 2 segments (e.g., com.lorenz)
- Can only contain lowercase letters, numbers, and underscores
- Each segment must start with a letter
- Cannot use reserved names (com.example, com.test, etc.)

## Steps to Change Package Name

### ⚠️ IMPORTANT: Do This BEFORE First Production Release

Changing the package name after publishing to Play Store creates a NEW app listing. Existing users cannot update.

---

### Step 1: Choose Your New Package Name

Decision: `______________________`

Example: `com.lorenz.motorcycleservice`

---

### Step 2: Update Android Files

#### 2.1 Update `android/app/build.gradle`

**File:** `android/app/build.gradle`

Find line 58:
```gradle
applicationId = "com.example.lorenz_app"
```

Change to:
```gradle
applicationId = "com.lorenz.motorcycleservice"  // Your new package name
```

#### 2.2 Update `AndroidManifest.xml`

**File:** `android/app/src/main/AndroidManifest.xml`

Find:
```xml
package="com.example.lorenz_app"
```

Change to:
```xml
package="com.lorenz.motorcycleservice"
```

#### 2.3 Rename Kotlin Package Directories

**Current structure:**
```
android/app/src/main/kotlin/com/example/lorenz_app/MainActivity.kt
```

**New structure (example):**
```
android/app/src/main/kotlin/com/lorenz/motorcycleservice/MainActivity.kt
```

**Commands:**
```bash
cd android/app/src/main/kotlin

# Create new directory structure
mkdir -p com/lorenz/motorcycleservice

# Move MainActivity.kt
mv com/example/lorenz_app/MainActivity.kt com/lorenz/motorcycleservice/

# Delete old directories
rm -rf com/example
```

#### 2.4 Update MainActivity.kt Package Declaration

**File:** `android/app/src/main/kotlin/com/lorenz/motorcycleservice/MainActivity.kt`

Change first line from:
```kotlin
package com.example.lorenz_app
```

To:
```kotlin
package com.lorenz.motorcycleservice
```

---

### Step 3: Update Firebase Configuration

#### 3.1 Register New Package in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **⚙️ Settings** → **Project settings**
4. Scroll to **Your apps**
5. Find Android app or click **Add app** → **Android**
6. Enter new package name: `com.lorenz.motorcycleservice`
7. Download NEW `google-services.json`

#### 3.2 Replace google-services.json

1. **Backup old file:**
   ```bash
   mv android/app/google-services.json android/app/google-services.json.backup
   ```

2. **Copy new file:**
   - Place downloaded `google-services.json` in `android/app/`

3. **Verify contents:**
   - Open `android/app/google-services.json`
   - Confirm `package_name` matches your new package name

---

### Step 4: Update iOS Bundle Identifier (Optional but Recommended)

For consistency, update iOS bundle identifier to match:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** project
3. Select **Runner** target
4. **General** tab → **Bundle Identifier**
5. Change to: `com.lorenz.motorcycleservice`

6. Update Firebase iOS app:
   - Firebase Console → iOS app settings
   - Add new bundle ID or update existing

---

### Step 5: Clean and Rebuild

```bash
# Clean everything
flutter clean

# Get dependencies
flutter pub get

# Clean Android build
cd android && ./gradlew clean && cd ..

# Rebuild
flutter build apk --debug
```

---

### Step 6: Test Thoroughly

1. **Test Debug Build:**
   ```bash
   flutter run --debug
   ```

2. **Test Release Build:**
   ```bash
   flutter build apk --release
   flutter install
   ```

3. **Verify Firebase Connection:**
   - Check logs for Firebase initialization
   - Test authentication (login/signup)
   - Test Firestore read/write
   - Test Google Sign-In

4. **Test App Signing:**
   - Ensure release build uses correct keystore
   - Verify ProGuard obfuscation works

---

### Step 7: Update Version Control

After successful testing:

```bash
git add .
git commit -m "Change package name from com.example.lorenz_app to com.lorenz.motorcycleservice"
```

---

## Verification Checklist

After making changes, verify:

- [ ] `android/app/build.gradle` → `applicationId` updated
- [ ] `android/app/src/main/AndroidManifest.xml` → `package` attribute updated
- [ ] `MainActivity.kt` → package declaration updated
- [ ] Kotlin package directories renamed
- [ ] New `google-services.json` with correct package_name
- [ ] Firebase Console shows app with new package name
- [ ] iOS bundle identifier updated (optional)
- [ ] Debug build works
- [ ] Release build works
- [ ] Firebase features work (Auth, Firestore, etc.)
- [ ] App signing works with release keystore
- [ ] Old package directories deleted

---

## Troubleshooting

### Error: "Default FirebaseApp is not initialized"

**Solution:**
- Ensure `google-services.json` has correct package name
- Run `flutter clean` and rebuild
- Check `package_name` in `google-services.json` matches `applicationId` in `build.gradle`

### Error: "MainActivity not found"

**Solution:**
- Verify package declaration in `MainActivity.kt` matches directory structure
- Ensure `AndroidManifest.xml` points to correct package

### Error: "Google Sign-In failed"

**Solution:**
- Download new `google-services.json` from Firebase
- Verify SHA-1 fingerprints registered in Firebase Console:
  ```bash
  # Get debug SHA-1
  cd android
  ./gradlew signingReport
  ```
- Add SHA-1 fingerprints to Firebase Console

### Build Fails After Package Name Change

**Solution:**
```bash
# Full clean
flutter clean
rm -rf build/
rm -rf android/.gradle/
rm -rf android/app/build/
cd android && ./gradlew clean && cd ..

# Rebuild
flutter pub get
flutter build apk --debug
```

---

## Important Notes

⚠️ **Firebase Impact:**
- Your app is already connected to Firebase with old package name
- Adding new package name to same Firebase project is FINE
- Old package registrations can remain (for testing)
- Production should use new package name only

⚠️ **Google Play Store:**
- New package name = new app listing
- Cannot transfer reviews/ratings
- Cannot merge with old package
- Choose wisely - package name is permanent!

⚠️ **Data Migration:**
- Firebase data is NOT tied to package name
- Your Firestore data will work with new package
- Users will need to reinstall app if package changes after release

---

## Quick Reference Commands

```bash
# Change package name in one place
# build.gradle line 58
applicationId = "com.lorenz.motorcycleservice"

# Rename directory structure
cd android/app/src/main/kotlin
mkdir -p com/lorenz/motorcycleservice
mv com/example/lorenz_app/MainActivity.kt com/lorenz/motorcycleservice/
rm -rf com/example

# Update MainActivity.kt first line
package com.lorenz.motorcycleservice

# Clean and rebuild
flutter clean && flutter pub get && flutter build apk --debug
```

---

## Current Status

- ❌ **Package name: com.example.lorenz_app** (MUST CHANGE)
- ⏳ **Recommended: com.lorenz.motorcycleservice**
- ⚠️ **Cannot publish to Play Store until changed**

---

## Need Help?

- [Flutter Package Name Change Guide](https://stackoverflow.com/questions/51534616/how-to-change-package-name-in-flutter)
- [Android Package Name Rules](https://developer.android.com/studio/build/application-id)
- [Firebase Android Setup](https://firebase.google.com/docs/android/setup)
