# 📱 Posto Fácil — Guia de Configuração

Consulte o arquivo SETUP_GUIDE.md para as instruções completas de instalação, configuração e publicação na Play Store.

## Estrutura do projeto

```
posto_facil/
├── lib/
│   ├── main.dart                       ← Ponto de entrada
│   ├── firebase_options.dart           ← Config Firebase (gerado pelo FlutterFire)
│   ├── models/
│   │   ├── gas_station.dart            ← Modelo de dados do posto
│   │   └── price_record.dart           ← Modelo de registro de preço
│   ├── services/
│   │   ├── auth_service.dart           ← Login com Google
│   │   ├── firestore_service.dart      ← Banco de dados Firebase
│   │   ├── location_service.dart       ← GPS e endereços
│   │   └── ocr_service.dart            ← Leitura de texto em fotos
│   └── screens/
│       ├── home_screen.dart            ← Tela inicial
│       ├── login_screen.dart           ← Tela de login
│       ├── map_screen.dart             ← Mapa de postos
│       ├── register_price_screen.dart  ← Registrar preço
│       └── station_detail_screen.dart  ← Detalhes do posto
├── android/
│   └── app/
│       ├── build.gradle
│       └── src/main/AndroidManifest.xml
└── pubspec.yaml
```

## Comandos essenciais

```bash
# Baixar dependências
flutter pub get

# Rodar no emulador/celular
flutter run

# Gerar APK para teste (instalar manualmente)
flutter build apk --debug

# Gerar AAB para Play Store
flutter build appbundle --release

# Verificar erros de instalação
flutter doctor
```
