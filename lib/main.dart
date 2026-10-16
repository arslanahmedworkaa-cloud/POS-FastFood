import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'welcome_screen.dart';

// Shared colors for the restaurant POS design.
const Color pizzaRed = Color(0xFFD93636);
const Color pizzaOrange = Color(0xFFFF8A3D);
const Color creamBackground = Color(0xFFFFF8F1);
const Color darkText = Color(0xFF292524);

void main() async {
  // Ensures Flutter is initialized before Firebase setup begins.
  WidgetsFlutterBinding.ensureInitialized();

  // Connects the app to the specified Firebase project.
  // "await" waits for Firebase initialization to finish before starting the app.
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBr_ojzFKMRSxYCDOOr7YybsgNAC4d_ZO8',
      appId: '1:270217833853:android:b91dd550970adee1e8f014',
      messagingSenderId: '270217833853',
      projectId: 'practice-7c8bc',
      storageBucket: 'practice-7c8bc.firebasestorage.app',
    ),
  );

  // Starts the app only after Firebase has been initialized.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Gets the current Firebase user.
    // If nobody is signed in, this value will be null.
    User? user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Applies shared styling without changing the app's existing functions.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: pizzaRed,
          brightness: Brightness.light,
        ).copyWith(
          primary: pizzaRed,
          secondary: pizzaOrange,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: creamBackground,

        // Gives app bars a clean appearance across the app.
        appBarTheme: const AppBarTheme(
          backgroundColor: creamBackground,
          foregroundColor: darkText,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: darkText,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Keeps text fields consistent without styling each one separately.
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE7DDD5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE7DDD5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: pizzaRed, width: 1.5),
          ),
        ),

        // Gives existing elevated buttons a consistent modern style.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: pizzaRed,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Uses the same accent color for existing text buttons.
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: pizzaRed,
          ),
        ),
      ),

      // Shows LoginScreen if no user is signed in;
      // otherwise, shows WelcomeScreen.
      home: user == null ? LoginScreen() : WelcomeScreen(),
    );
  }
}
