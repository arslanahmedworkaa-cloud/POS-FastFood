import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const pizzaRed = Color(0xFFD93636);
const pizzaOrange = Color(0xFFFF8A3D);
const creamBackground = Color(0xFFFFF8F1);
const darkText = Color(0xFF292524);

class DeleteCategoryScreen extends StatelessWidget {
  const DeleteCategoryScreen({super.key});

  User? get currentUser => FirebaseAuth.instance.currentUser;

  CollectionReference get categoriesCollection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('categories');
  }

  void showDeleteDialog(BuildContext context, String categoryId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Delete Category',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this category?',
            style: TextStyle(color: darkText),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(
                foregroundColor: darkText,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  await categoriesCollection.doc(categoryId).delete();

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category deleted successfully'),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: pizzaRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: creamBackground,
        body: Center(child: Text('User is not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: AppBar(
        title: const Text(
          'Delete Category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: pizzaRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: categoriesCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: pizzaRed),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

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
                style: TextStyle(
                  fontSize: 18,
                  color: darkText,
                ),
              ),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: darkText.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Table(
                border: TableBorder.all(
                  color: const Color(0xFFE7D8CC),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(100),
                  1: FixedColumnWidth(130),
                  2: FixedColumnWidth(100),
                  3: FixedColumnWidth(110),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      color: creamBackground,
                    ),
                    children: const [
                      _DeleteHeaderCell('Category ID'),
                      _DeleteHeaderCell('Category Name'),
                      _DeleteHeaderCell('Image'),
                      _DeleteHeaderCell('Action'),
                    ],
                  ),
                  ...categories.map((category) {
                    final data = category.data() as Map<String, dynamic>;

                    final String categoryId = data['categoryId'] ?? '';
                    final String categoryName = data['categoryName'] ?? '';
                    final String categoryImage = data['categoryImage'] ?? '';

                    return TableRow(
                      children: [
                        _DeleteBodyCell(categoryId),
                        _DeleteBodyCell(categoryName),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: categoryImage.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(categoryImage),
                                    height: 60,
                                    width: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) {
                                      return const Icon(
                                        Icons.broken_image_outlined,
                                        color: pizzaOrange,
                                        size: 35,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.image_outlined,
                                  color: pizzaOrange,
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: ElevatedButton(
                            onPressed: () {
                              showDeleteDialog(context, categoryId);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pizzaRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DeleteHeaderCell extends StatelessWidget {
  final String text;

  const _DeleteHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: pizzaRed,
        ),
      ),
    );
  }
}

class _DeleteBodyCell extends StatelessWidget {
  final String text;

  const _DeleteBodyCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(color: darkText),
        ),
      ),
    );
  }
}
