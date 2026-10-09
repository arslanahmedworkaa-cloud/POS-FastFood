import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ListCategoriesScreen extends StatelessWidget {
  const ListCategoriesScreen({super.key});

  // Gets the currently logged-in Firebase user.
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Opens the categories collection belonging to the current user.
  CollectionReference get categoriesCollection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('categories');
  }

  @override
  Widget build(BuildContext context) {
    // Prevents loading categories when no user is logged in.
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('User is not logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('List Categories'),
        backgroundColor: Colors.orangeAccent,
      ),
      // Listens for category changes in Firestore in real time.
      body: StreamBuilder<QuerySnapshot>(
        stream: categoriesCollection.snapshots(),
        builder: (context, snapshot) {
          // Shows a loader while categories are being fetched.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Displays an error if Firestore cannot load the categories.
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          // Keeps only documents that contain the required category fields.
          final categories = snapshot.data?.docs.where((category) {
                final data = category.data() as Map<String, dynamic>;

                return data.containsKey('categoryId') &&
                    data.containsKey('categoryName') &&
                    data.containsKey('categoryImage');
              }).toList() ??
              [];

          // Shows a message when there are no categories to display.
          if (categories.isEmpty) {
            return const Center(
              child: Text(
                'No categories added yet',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Table(
              border: TableBorder.all(
                color: Colors.grey,
              ),
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Category ID',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Category Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Category Image',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                // Creates one table row for each category.
                ...categories.map((category) {
                  final data = category.data() as Map<String, dynamic>;

                  String categoryId = data['categoryId'] ?? '';

                  String categoryName = data['categoryName'] ?? '';

                  String categoryImage = data['categoryImage'] ?? '';

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(categoryId),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(categoryName),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        // Converts the saved Base64 image back into bytes for display.
                        child: categoryImage.isNotEmpty
                            ? Image.memory(
                                base64Decode(categoryImage),
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image),
                      ),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      ),
      backgroundColor: Color(0xffc6d1d7),
    );
  }
}
