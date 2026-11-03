import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// Generated Firebase options for the focus-or-roast project.
/// Matches android/app/google-services.json (package: com.example.focus_or_roast)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCUx9cnkEhNckpG6B2jA_JjWKhipryatns',
    appId: '1:1089992639110:android:99a8710d3dc9e7d70a4707',
    messagingSenderId: '1089992639110',
    projectId: 'focus-or-roast',
    storageBucket: 'focus-or-roast.firebasestorage.app',
  );
}
