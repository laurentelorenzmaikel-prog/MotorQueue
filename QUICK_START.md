# Lorenz App - Quick Start Guide

## 🚀 Get Running in 5 Minutes

### 1. Setup Environment (1 min)

```bash
cd c:\Users\senku\OneDrive\Desktop\lorenz\lorenz_app
copy .env.example .env
notepad .env
```

Add your OpenRouter API key (IMPORTANT: Rotate the exposed key first!)

### 2. Install Dependencies (1 min)

```bash
flutter pub get
```

### 3. Deploy Firestore Indexes (1 min)

```bash
firebase login
firebase deploy --only firestore:indexes
```

### 4. Create Admin User (1 min)

```bash
dart run scripts/create_admin.dart
```

Follow prompts to create admin account.

### 5. Run the App (1 min)

```bash
# Start Android emulator first
flutter run
```

**Login with your admin credentials to access the dashboard!**

---

## 📱 Testing the Predictions Feature

1. Login as admin
2. Click "Predictions" in sidebar
3. If no data: Create some test bookings first
   - Logout, create regular user
   - Book 5-10 appointments for different services
   - Login as admin again
4. View AI-powered predictions and insights!

---

## ⚠️ Critical Security Note

**IMMEDIATELY rotate the exposed OpenRouter API key:**
1. Go to https://openrouter.ai/keys
2. Delete old key
3. Create new key
4. Update `.env` file

---

## 🐛 Troubleshooting

**Admin page not loading?**
- Check that user has `role: "admin"` in Firestore
- Verify email is verified
- Check session hasn't expired (8-hour limit)

**Predictions page empty?**
- Create test booking data
- Refresh the page (pull-to-refresh)

**Build errors?**
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📚 Full Documentation

See [FIXES_AND_SETUP.md](FIXES_AND_SETUP.md) for complete details.

---

**Need help?** Check the detailed guide or review console logs for specific errors.
