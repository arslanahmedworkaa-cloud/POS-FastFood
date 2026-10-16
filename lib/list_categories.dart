import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const pizzaRed = Color(0xFFD93636);
const pizzaOrange = Color(0xFFFF8A3D);
const creamBackground = Color(0xFFFFF8F1);
const darkText = Color(0xFF292524);

class ListCategoriesScreen extends StatelessWidget {
  const ListCategoriesScreen({super.key});

  User? get currentUser => FirebaseAuth.instance.currentUser;

  CollectionReference get categoriesCollection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('categories');
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
          'List Categories',
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
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
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
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      color: creamBackground,
                    ),
                    children: const [
                      _ListHeaderCell('Category ID'),
                      _ListHeaderCell('Category Name'),
                      _ListHeaderCell('Category Image'),
                    ],
                  ),
                  ...categories.map((category) {
                    final data = category.data() as Map<String, dynamic>;

                    final String categoryId = data['categoryId'] ?? '';
                    final String categoryName = data['categoryName'] ?? '';
                    final String categoryImage = data['categoryImage'] ?? '';

                    return TableRow(
                      children: [
                        _ListBodyCell(categoryId),
                        _ListBodyCell(categoryName),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: categoryImage.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(categoryImage),
                                    height: 65,
                                    width: 65,
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
                                  size: 35,
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

class _ListHeaderCell extends StatelessWidget {
  final String text;

  const _ListHeaderCell(this.text);

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

class _ListBodyCell extends StatelessWidget {
  final String text;

  const _ListBodyCell(this.text);

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
