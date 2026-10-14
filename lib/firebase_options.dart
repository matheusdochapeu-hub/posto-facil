// ATENÇÃO: Este arquivo será gerado automaticamente pelo FlutterFire CLI
// após você configurar seu projeto Firebase.
// Por enquanto é um placeholder (substituto temporário).
// Siga o SETUP_GUIDE.md para gerar o arquivo real.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ⚠️ SUBSTITUA ESTES VALORES pelos do seu projeto Firebase!
  // Veja o SETUP_GUIDE.md para instruções detalhadas.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'SUA_API_KEY_AQUI',
    appId: 'SEU_APP_ID_AQUI',
    messagingSenderId: 'SEU_SENDER_ID_AQUI',
    projectId: 'SEU_PROJECT_ID_AQUI',
    storageBucket: 'SEU_BUCKET_AQUI.appspot.com',
  );
}
