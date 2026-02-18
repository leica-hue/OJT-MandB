// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase config for mandb-maligaya (web only).
/// Get apiKey, appId, messagingSenderId from Firebase Console → Project settings → Your apps
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCbDVydfPYYqEJ5LKm1p0yqK7xuiWkC3Wk',
    appId: '1:602111663557:web:1c24c7f8fc64be1d343fac',
    messagingSenderId: '602111663557',
    projectId: 'mandb-maligaya',
    authDomain: 'mandb-maligaya.firebaseapp.com',
    storageBucket: 'mandb-maligaya.appspot.com',
    measurementId: 'G-9ZW1BDR3C7',
  );
}
