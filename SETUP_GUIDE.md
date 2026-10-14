# 📱 Guia Completo — Posto Fácil v1.0

> Guia para quem **não tem experiência** em programação.
> Todos os termos técnicos são explicados.

---

## 📋 O que você vai precisar

| O que | Custo | Link |
|---|---|---|
| Computador com Windows 10/11 | — | — |
| Flutter SDK | Gratuito | https://flutter.dev/docs/get-started/install/windows |
| Android Studio | Gratuito | https://developer.android.com/studio |
| Conta Google (Gmail) | Gratuito | — |
| Conta Firebase | Gratuito | https://firebase.google.com |
| Conta Google Play Console | ~R$ 125 (taxa única) | https://play.google.com/console |

---

## PASSO 1 — Instalar o Flutter

**Flutter** é a ferramenta que vai transformar o código em um app Android.

### 1.1 Baixar o Flutter
1. Acesse: https://flutter.dev/docs/get-started/install/windows
2. Clique em **"Download Flutter SDK"**
3. Extraia o arquivo ZIP em `C:\flutter` (crie essa pasta)
4. **IMPORTANTE:** Não coloque em pastas com espaço no nome

### 1.2 Adicionar ao PATH
*PATH é a lista de programas que o Windows reconhece no terminal*

1. Pressione `Win + S`, busque **"Variáveis de ambiente"**
2. Clique em **"Editar as variáveis de ambiente do sistema"**
3. Clique em **"Variáveis de Ambiente..."**
4. Em "Variáveis do usuário", clique em **Path** → **Editar**
5. Clique em **Novo** e adicione: `C:\flutter\bin`
6. Clique **OK** em todas as janelas

### 1.3 Verificar a instalação
1. Pressione `Win + R`, digite `cmd` e aperte Enter
2. No terminal que abrir, digite:
```
flutter doctor
```
3. Esse comando vai mostrar o que ainda falta instalar

---

## PASSO 2 — Instalar o Android Studio

**Android Studio** é o programa que permite criar e testar apps Android.

1. Acesse: https://developer.android.com/studio
2. Baixe e instale o Android Studio
3. Na instalação, aceite todas as configurações padrão
4. Ao abrir o Android Studio pela primeira vez, siga o assistente de configuração

### 2.1 Instalar um emulador Android
*Emulador = celular virtual no computador para testar o app*

1. No Android Studio, clique em **"Device Manager"** (ícone de celular na barra lateral)
2. Clique em **"+"** → **"Create Virtual Device"**
3. Escolha **"Pixel 7"** → Next
4. Escolha a versão do Android mais recente → Download (se necessário) → Next
5. Clique **Finish**

---

## PASSO 3 — Criar o Projeto Firebase

**Firebase** é o servidor/banco de dados do app na nuvem (da Google).

1. Acesse: https://console.firebase.google.com
2. Clique em **"Criar um projeto"**
3. Nome do projeto: `posto-facil` (sem acentos)
4. Desative o Google Analytics (pode ativar depois) → **Criar projeto**

### 3.1 Configurar Autenticação (Login)

1. No menu lateral, clique em **"Authentication"**
2. Clique em **"Primeiros passos"**
3. Na aba **"Método de login"**, clique em **Google**
4. Ative o toggle e preencha o e-mail de suporte
5. Salve

### 3.2 Configurar o Banco de Dados (Firestore)

1. No menu lateral, clique em **"Firestore Database"**
2. Clique em **"Criar banco de dados"**
3. Escolha **"Iniciar no modo de produção"**
4. Selecione a região: **`us-east1`** (mais próxima do Brasil com bom desempenho)
5. Clique **Ativar**

#### Regras de segurança do Firestore
Após criar o banco, vá em **Regras** e cole isso:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /gas_stations/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /price_records/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```
Clique **Publicar**.

### 3.3 Configurar o Armazenamento de Fotos (Storage)

1. No menu lateral, clique em **"Storage"**
2. Clique em **"Primeiros passos"**
3. Aceite as regras padrão / escolha a região `us-east1`

#### Regras do Storage
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /price_photos/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### 3.4 Conectar o Firebase ao App Flutter

1. Instale o Node.js em: https://nodejs.org (versão LTS)
2. Abra o terminal (Win + R → cmd) e instale o FlutterFire CLI:
```
dart pub global activate flutterfire_cli
```
3. Navegue até a pasta do projeto:
```
cd "C:\Users\matheus.ribeiro\Desktop\Matheus\5. IA\Posto Gasolina\posto_facil"
```
4. Execute:
```
flutterfire configure
```
5. Siga as instruções, escolhendo seu projeto Firebase
6. Isso vai **substituir automaticamente** o arquivo `firebase_options.dart` com suas configurações reais

---

## PASSO 4 — Configurar o Google Maps

1. Acesse: https://console.cloud.google.com
2. Selecione o mesmo projeto do Firebase
3. No menu, vá em **"APIs e Serviços"** → **"Biblioteca"**
4. Busque e ative:
   - **"Maps SDK for Android"**
   - **"Geocoding API"**
5. Vá em **"APIs e Serviços"** → **"Credenciais"**
6. Clique em **"Criar credenciais"** → **"Chave de API"**
7. Copie a chave gerada

### 4.1 Adicionar a chave no app
Abra: `posto_facil/android/app/src/main/AndroidManifest.xml`
Encontre e substitua:
```
android:value="SUA_CHAVE_GOOGLE_MAPS_AQUI"
```
pela sua chave real.

---

## PASSO 5 — Rodar o App pela Primeira Vez

1. Abra o terminal na pasta do projeto:
```
cd "C:\Users\matheus.ribeiro\Desktop\Matheus\5. IA\Posto Gasolina\posto_facil"
```
2. Baixe todas as dependências:
```
flutter pub get
```
3. Inicie o emulador no Android Studio
4. Rode o app:
```
flutter run
```

---

## PASSO 6 — Publicar na Play Store

> Só faça isso quando o app estiver testado e pronto.

### 6.1 Criar conta de desenvolvedor
1. Acesse: https://play.google.com/console
2. Faça login com sua conta Google
3. Pague a taxa (~$25 USD / ~R$ 125)
4. Preencha o perfil do desenvolvedor

### 6.2 Criar o keystore (assinatura digital)
**GUARDE ESTE ARQUIVO E A SENHA EM LOCAL SEGURO!**

No terminal:
```
keytool -genkey -v -keystore posto-facil-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias posto-facil
```

### 6.3 Gerar o arquivo para publicação (AAB)
```
flutter build appbundle --release
```
O arquivo ficará em: `build/app/outputs/bundle/release/app-release.aab`

### 6.4 Criar o app na Play Store
1. No Google Play Console → "Criar app"
2. Preencha nome, descrição, screenshots, ícone (512x512px)
3. Complete a classificação etária e Política de Privacidade
4. Vá em **"Versões"** → **"Produção"** → **"Criar nova versão"**
5. Faça upload do `app-release.aab`
6. Aguarde revisão do Google (3 a 7 dias úteis)

---

## Onde buscar ajuda

| Recurso | Link |
|---|---|
| Documentação Flutter | https://flutter.dev/docs |
| Comunidade Flutter BR (Telegram) | https://t.me/flutterbrasil |
| YouTube: Flutterando | https://www.youtube.com/@Flutterando |
| Firebase Docs em PT | https://firebase.google.com/docs?hl=pt-br |
