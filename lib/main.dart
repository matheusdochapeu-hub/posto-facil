import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  // Garante que o Flutter está pronto antes de inicializar o Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase (banco de dados na nuvem)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PostoFacilApp());
}

class PostoFacilApp extends StatelessWidget {
  const PostoFacilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posto Fácil',
      debugShowCheckedModeBanner: false,

      // Tema visual do app (verde = combustível/natureza)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20), // Verde escuro
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFFFFA000), // Amarelo âmbar
          surface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      // Decide qual tela mostrar: login ou tela principal
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Está carregando...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Usuário logado → vai para tela principal
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }

          // Não logado → vai para tela de login
          return const LoginScreen();
        },
      ),
    );
  }
}
