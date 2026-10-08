// File generated for Sanchay Wealth App
// Using live Firebase project: gen-lang-client-0521710909

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDQoXFWNkfheddNiDs0GHFah2shDelMcxg',
    appId: '1:41954701104:web:2d6b37717e4204d02fe2f5',
    messagingSenderId: '41954701104',
    projectId: 'gen-lang-client-0521710909',
    authDomain: 'gen-lang-client-0521710909.firebaseapp.com',
    storageBucket: 'gen-lang-client-0521710909.firebasestorage.app',
    measurementId: 'G-YQD967Q8WR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBfdgixiQZgZFDqYaePDJ25dzXHQ7CXVKs',
    appId: '1:41954701104:android:4575462b4e58e7bc2fe2f5',
    messagingSenderId: '41954701104',
    projectId: 'gen-lang-client-0521710909',
    storageBucket: 'gen-lang-client-0521710909.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDQoXFWNkfheddNiDs0GHFah2shDelMcxg',
    appId: '1:41954701104:web:2d6b37717e4204d02fe2f5',
    messagingSenderId: '41954701104',
    projectId: 'gen-lang-client-0521710909',
    storageBucket: 'gen-lang-client-0521710909.firebasestorage.app',
  );
}
