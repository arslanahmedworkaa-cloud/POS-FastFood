import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteCategoryScreen extends StatelessWidget {
  const DeleteCategoryScreen({super.key});

  // Gets the currently logged-in Firebase user.
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Opens the categories collection belonging to the current user.
  CollectionReference get categoriesCollection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('categories');
  }

  void showDeleteDialog(
    BuildContext context,
    String categoryId,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: const Text(
            'Are you sure you want to delete this category?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Closes the dialog without deleting the category.
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Closes the confirmation dialog before deleting the document.
                Navigator.pop(context);

                try {
                  // Deletes the selected category document from Firestore.
                  await categoriesCollection.doc(categoryId).delete();

                  // Stops if the context is no longer available.
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Category deleted successfully',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prevents category data from being accessed when no user is logged in.
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('User is not logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Category'),
        backgroundColor: Colors.orangeAccent,
      ),
      // Listens for category changes in Firestore and updates the screen automatically.
      body: StreamBuilder<QuerySnapshot>(
        stream: categoriesCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          // Keeps only documents that contain all required category fields.
          final categories = snapshot.data?.docs.where((category) {
                final data = category.data() as Map<String, dynamic>;

                return data.containsKey('categoryId') &&
                    data.containsKey('categoryName') &&
                    data.containsKey('categoryImage');
              }).toList() ??
              [];

          if (categories.isEmpty) {
            return const Center(
              child: Text(
                'No categories added yet',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(20),
            child: Table(
              border: TableBorder.all(
                color: Colors.grey,
              ),
              columnWidths: const {
                0: FixedColumnWidth(80),
                1: FixedColumnWidth(80),
                2: FixedColumnWidth(80),
                3: FixedColumnWidth(105),
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
                        'Image',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Action',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
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
                        child: categoryImage.isNotEmpty
                            // Converts the saved Base64 string back into image bytes.
                            ? Image.memory(
                                base64Decode(categoryImage),
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          onPressed: () {
                            // Opens the confirmation dialog for this category.
                            showDeleteDialog(
                              context,
                              categoryId,
                            );
                          },
                          child: const Text('Delete'),
                        ),
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
