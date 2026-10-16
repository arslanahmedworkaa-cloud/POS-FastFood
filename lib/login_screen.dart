import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'welcome_screen.dart';

// Colors for the restaurant POS design.
const Color pizzaRed = Color(0xFFD93636);
const Color darkText = Color(0xFF292524);

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
      // Allows the login form to scroll on smaller screens.
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Adds a small restaurant-themed icon above the login form.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE7DF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.local_pizza_rounded,
                      size: 44,
                      color: pizzaRed,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Welcome Back!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to your restaurant POS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF78716C),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Groups the existing login fields and button in a simple card.
                  Card(
                    color: Colors.white,
                    elevation: 1,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                        color: Color(0xFFF0E4DB),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              // Runs the original login function when pressed.
                              onPressed: login,
                              child: const Text('Login'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
          ),
        ),
      ),
    );
  }
}
