import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError('DefaultFirebaseOptions no soporta esta plataforma');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB71eL98aIT_lMKgqA_e-3G7SjOZxYHagE',
    authDomain: 'tesoreria-iglesia-b6c08.firebaseapp.com',
    projectId: 'tesoreria-iglesia-b6c08',
    storageBucket: 'tesoreria-iglesia-b6c08.firebasestorage.app',
    messagingSenderId: '803329663395',
    appId: '1:803329663395:web:e0b1ac0241143c2c3f7a16',
  );
}