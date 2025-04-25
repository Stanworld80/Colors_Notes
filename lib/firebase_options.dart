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
    apiKey: 'AIzaSyCiBDq19Is5aF9B274aJt-52hdzo3mi2cE',
    appId: '1:603607348131:web:fe69e76947710f930b2016',
    messagingSenderId: '603607348131',
    projectId: 'soa-starter-d9688',
    authDomain: 'soa-starter-d9688.firebaseapp.com',
    storageBucket: 'soa-starter-d9688.firebasestorage.app',
    measurementId: 'G-QGVF2XQ847',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBtG7cx11DZYxGRnQ5H81G03eG2rPbaiOo',
    appId: '1:603607348131:android:947d57547b03bbb10b2016',
    messagingSenderId: '603607348131',
    projectId: 'soa-starter-d9688',
    storageBucket: 'soa-starter-d9688.firebasestorage.app',
  );

}