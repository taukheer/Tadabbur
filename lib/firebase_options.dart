import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAQxyXZiEbw5SzXLhtJ262oXHviNIJc0OM',
    appId: '1:636345975934:android:3366271a73de5e6299042f',
    messagingSenderId: '636345975934',
    projectId: 'tadabbur-492408',
    storageBucket: 'tadabbur-492408.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAQxyXZiEbw5SzXLhtJ262oXHviNIJc0OM',
    appId: '1:636345975934:android:3366271a73de5e6299042f',
    messagingSenderId: '636345975934',
    projectId: 'tadabbur-492408',
    storageBucket: 'tadabbur-492408.firebasestorage.app',
    iosBundleId: 'com.tadabbur.tadabbur',
  );
}
