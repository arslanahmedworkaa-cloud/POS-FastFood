import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Controllers provide access to the values entered by the user.
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Creates a Firebase account and then saves the user's details in Firestore.
  void signup() async {
    // Checks the trimmed password length before sending it to Firebase.
    // Firebase email/password accounts require a password of at least 6 characters.
    if (passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    try {
      // Creates the account in Firebase Authentication using the entered email and password.
      // The returned result contains information about the newly created account.
      UserCredential result =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Saves the username and email in the "users" collection in Firestore.
      // The user's Firebase UID is used as the document ID, linking these details
      // to the account that was just created.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .set({
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
      });

      // Returns to the previous screen after the signup process completes.
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      // Displays the error message returned by Firebase Authentication.
      // Uses "Signup failed" if Firebase does not provide an error message.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Signup failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              // Starts account creation and saves the user's details when pressed.
              onPressed: signup,
              child: Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
