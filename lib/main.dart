import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'welcome_screen.dart';

void main() async {
  // Ensures Flutter is initialized before Firebase setup begins.
  WidgetsFlutterBinding.ensureInitialized();

  // Connects the app to the specified Firebase project.
  // "await" waits for Firebase initialization to finish before starting the app.
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBr_ojzFKMRSxYCDOOr7YybsgNAC4d_Z8',
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

      // Shows LoginScreen if no user is signed in;
      // otherwise, shows WelcomeScreen.
      home: user == null ? LoginScreen() : WelcomeScreen(),
    );
  }
}
