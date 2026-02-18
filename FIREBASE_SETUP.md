# Firebase Setup Instructions

Your app is configured to use Firebase. Complete these steps to connect it to your Firebase project:

## 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Enable **Google Analytics** (optional)

## 2. Enable Authentication

1. In Firebase Console, go to **Build** → **Authentication**
2. Click **Get started**
3. Go to **Sign-in method** tab
4. Enable **Email/Password** provider

## 3. Enable Firestore (for user profiles)

1. In Firebase Console, go to **Build** → **Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** (for development) or **Production mode**
4. Select a region

## 4. Add Your App to Firebase

### Web
1. In Project settings (gear icon), click **Add app** → **Web** (</>)
2. Register app with a nickname
3. Copy the `firebaseConfig` values

### Android (if building for Android)
1. Click **Add app** → **Android**
2. Package name: `com.example.test` (or your app's package name from `android/app/build.gradle`)
3. Download `google-services.json` and place it in `android/app/`

### iOS (if building for iOS)
1. Click **Add app** → **iOS**
2. Bundle ID: `com.example.test` (or your app's bundle ID)
3. Download `GoogleService-Info.plist` and add it to the `ios/Runner` folder in Xcode

## 5. Configure FlutterFire

Run this command in your project directory:

```bash
dart run flutterfire_cli:flutterfire configure
```

This will:
- Log you into Firebase (if not already)
- Let you select your Firebase project
- Generate `lib/firebase_options.dart` with your project's credentials
- Create/update platform configuration files

**Note:** If the command fails (e.g., due to Git not being in PATH), you can manually update `lib/firebase_options.dart` with the values from your Firebase Console project settings.

## 6. Update firebase_options.dart (if not using FlutterFire CLI)

If you couldn't run `flutterfire configure`, manually replace the placeholder values in `lib/firebase_options.dart` with your Firebase project credentials from **Project settings** → **Your apps** in the Firebase Console.

## 7. Run the App

```bash
flutter run -d chrome
# or
flutter run -d windows
```

## Firestore Security Rules (login-accounts)

For the `login-accounts` collection to accept writes, add these rules in Firebase Console → Firestore Database → Rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /login-accounts/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

This lets each user read/write only their own document.

## Troubleshooting

- **"Firebase not initialized"**: Make sure you've completed step 5 and `firebase_options.dart` has real values (not placeholders)
- **"Email/password sign-in is disabled"**: Enable it in Authentication → Sign-in method
- **"Permission denied" on Firestore**: Add the security rules above or use test mode for development
