import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers let the login function read the values entered in these fields.
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // Handles the complete login process.
  void login() async {
    try {
      // Searches Firestore's "users" collection for the entered username.
      // trim() removes extra spaces from the beginning and end.
      // limit(1) requests at most one matching document, and get() fetches it.
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: usernameController.text.trim())
          .limit(1)
          .get();

      // If no matching username exists, show an error and stop the function.
      if (result.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid username or password'),
          ),
        );
        return;
      }

      // Reads the email stored in the matching Firestore document.
      // This email is needed because Firebase Authentication signs in with email and password.
      String email = result.docs.first['email'];

      // Verifies the stored email and entered password with Firebase Authentication.
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: passwordController.text.trim(),
      );

      // Makes sure this screen still exists before using its context.
      if (!mounted) return;

      // Opens the welcome screen after successful authentication.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WelcomeScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      // Handles Firebase Authentication errors, such as invalid login credentials.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Code: ${e.code}\nMessage: ${e.message}',
          ),
        ),
      );
    } catch (e) {
      // Handles other errors that were not caught as FirebaseAuthException.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Other Error: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Login',
              style: TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              // Runs the login function when the user presses Login.
              onPressed: login,
              child: const Text('Login'),
            ),
            const SizedBox(height: 10),
            TextButton(
              // Opens the signup screen for users who need to create an account.
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignupScreen(),
                  ),
                );
              },
              child: const Text(
                'Don\'t have an account? Sign up',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
