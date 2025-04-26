import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyByKR0NTLjEd-4BHaYeh3pDoq1RtSg4WRg',
    appId: '1:523869870608:web:d2d1a5bd6129e325bbc895',
    messagingSenderId: '523869870608',
    projectId: 'colorsnotes-e9142',
    authDomain: 'colorsnotes-e9142.firebaseapp.com',
    storageBucket: 'colorsnotes-e9142.firebasestorage.app',
    measurementId: 'G-0X0ZKKG9MZ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB8e2IdFFWKKyLdwQGf-bvxhRKZmWzxdKI',
    appId: '1:523869870608:android:c40003ada691cab0bbc895',
    messagingSenderId: '523869870608',
    projectId: 'colorsnotes-e9142',
    storageBucket: 'colorsnotes-e9142.firebasestorage.app',
  );

}