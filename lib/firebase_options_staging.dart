// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
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
    apiKey: 'AIzaSyAntVC99HD_XpyXm2W6I56V2k6IRuTEOd0',
    appId: '1:344541548510:web:e89b22d9170899677d174f',
    messagingSenderId: '344541548510',
    projectId: 'colors-notes-staging',
    authDomain: 'colors-notes-staging.firebaseapp.com',
    storageBucket: 'colors-notes-staging.firebasestorage.app',
    measurementId: 'G-67Y85S536V',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCM4qYI0VtSAHTeorJzNMEwFHXAjEAMKbA',
    appId: '1:344541548510:android:631fa078fb9926677d174f',
    messagingSenderId: '344541548510',
    projectId: 'colors-notes-staging',
    storageBucket: 'colors-notes-staging.firebasestorage.app',
  );
}
