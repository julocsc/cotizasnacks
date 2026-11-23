// Plantilla de configuración de Firebase.
//
// IMPORTANTE:
// Ejecuta `flutterfire configure --platforms=android,web` desde la raíz del
// proyecto. El CLI reemplazará este archivo con los valores reales de tu
// proyecto de Firebase. También puedes editar los valores manualmente.
//
// Los valores de ejemplo empiezan con `REPLACE_` para que la app muestre una
// pantalla de configuración en lugar de fallar de forma confusa.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Esta configuración solo incluye Android y Web. '
          'Ejecuta flutterfire configure para agregar otra plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC63dEbscgTQD-zByAFtRq40QWbHi5AgHg',
    appId: '1:612752510964:web:3a09071ba333360e2af3a1',
    messagingSenderId: '612752510964',
    projectId: 'cotizacion-317a1',
    authDomain: 'cotizacion-317a1.firebaseapp.com',
    storageBucket: 'cotizacion-317a1.firebasestorage.app',
    measurementId: 'G-B4QM91M0XQ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCWId_RDXZEPFjbBYYTITNDNB1Msgsej34',
    appId: '1:612752510964:android:e587dbe03670217d2af3a1',
    messagingSenderId: '612752510964',
    projectId: 'cotizacion-317a1',
    storageBucket: 'cotizacion-317a1.firebasestorage.app',
  );
}
