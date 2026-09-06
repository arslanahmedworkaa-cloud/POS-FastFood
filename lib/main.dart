import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBr_ojzFKMRSxYCDOOr7YybsgNAC4d_ZO8',
      appId: '1:270217833853:android:b91dd550970adee1e8f014',
      messagingSenderId: '270217833853',
      projectId: 'practice-7c8bc',
      storageBucket: 'practice-7c8bc.firebasestorage.app',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: user == null ? LoginScreen() : WelcomeScreen(),
    );
  }
}
