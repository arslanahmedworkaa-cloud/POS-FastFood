import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class EditCategoryScreen extends StatelessWidget {
  const EditCategoryScreen({super.key});

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
        body: Center(
          child: Text('User is not logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Category'),
        backgroundColor: Colors.orangeAccent,
      ),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditCategoryForm(
                                  categoryId: categoryId,
                                  categoryName: categoryName,
                                  categoryImage: categoryImage,
                                ),
                              ),
                            );
                          },
                          child: const Text('Edit'),
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
    );
  }
}

class EditCategoryForm extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String categoryImage;

  const EditCategoryForm({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryImage,
  });

  @override
  State<EditCategoryForm> createState() => _EditCategoryFormState();
}

class _EditCategoryFormState extends State<EditCategoryForm> {
  late TextEditingController idController;
  late TextEditingController nameController;

  Uint8List? selectedImage;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    idController = TextEditingController(
      text: widget.categoryId,
    );

    nameController = TextEditingController(
      text: widget.categoryName,
    );
  }

  Future<void> selectImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 50,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    setState(() {
      selectedImage = bytes;
    });
  }

  Future<void> updateCategory() async {
    String categoryName = nameController.text.trim();

    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Category Name'),
        ),
      );
      return;
    }

    if (currentUser == null) {
      return;
    }

    try {
      String imageToSave = widget.categoryImage;

      if (selectedImage != null) {
        imageToSave = base64Encode(selectedImage!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('categories')
          .doc(widget.categoryId)
          .update({
        'categoryName': categoryName,
        'categoryImage': imageToSave,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category updated successfully'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    idController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Category'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Table(
              border: TableBorder.all(
                color: Colors.grey,
              ),
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Category ID',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        controller: idController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Category Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Category Image',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          if (selectedImage != null)
                            Image.memory(
                              selectedImage!,
                              height: 120,
                              width: 120,
                              fit: BoxFit.cover,
                            )
                          else if (widget.categoryImage.isNotEmpty)
                            Image.memory(
                              base64Decode(
                                widget.categoryImage,
                              ),
                              height: 120,
                              width: 120,
                              fit: BoxFit.cover,
                            )
                          else
                            const Icon(
                              Icons.image,
                              size: 80,
                              color: Colors.grey,
                            ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: selectImage,
                            child: const Text('Change Image'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: updateCategory,
                child: const Text('Update'),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Color(0xffc6d1d7),
    );
  }
}
