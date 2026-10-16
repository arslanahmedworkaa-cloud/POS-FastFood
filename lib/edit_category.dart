import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

const pizzaRed = Color(0xFFD93636);
const pizzaOrange = Color(0xFFFF8A3D);
const creamBackground = Color(0xFFFFF8F1);
const darkText = Color(0xFF292524);

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
        backgroundColor: creamBackground,
        body: Center(child: Text('User is not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: AppBar(
        title: const Text(
          'Edit Category',
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
                  3: FixedColumnWidth(105),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      color: creamBackground,
                    ),
                    children: const [
                      _HeaderCell('Category ID'),
                      _HeaderCell('Category Name'),
                      _HeaderCell('Image'),
                      _HeaderCell('Action'),
                    ],
                  ),
                  ...categories.map((category) {
                    final data = category.data() as Map<String, dynamic>;

                    final String categoryId = data['categoryId'] ?? '';
                    final String categoryName = data['categoryName'] ?? '';
                    final String categoryImage = data['categoryImage'] ?? '';

                    return TableRow(
                      children: [
                        _BodyCell(categoryId),
                        _BodyCell(categoryName),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pizzaOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Edit'),
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

    idController = TextEditingController(text: widget.categoryId);
    nameController = TextEditingController(text: widget.categoryName);
  }

  InputDecoration fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: creamBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE7D8CC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE7D8CC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: pizzaRed, width: 1.5),
      ),
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

    if (image == null) return;

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    setState(() {
      selectedImage = bytes;
    });
  }

  Future<void> updateCategory() async {
    final String categoryName = nameController.text.trim();

    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Category Name')),
      );
      return;
    }

    if (currentUser == null) return;

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
        const SnackBar(content: Text('Category updated successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
      backgroundColor: creamBackground,
      appBar: AppBar(
        title: const Text(
          'Edit Category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: pizzaRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: darkText.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Category Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Category ID',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: idController,
                readOnly: true,
                decoration: fieldDecoration('Category ID'),
              ),
              const SizedBox(height: 18),
              const Text(
                'Category Name',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: fieldDecoration('Enter Category Name'),
              ),
              const SizedBox(height: 22),
              const Text(
                'Category Image',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 180,
                  height: 155,
                  decoration: BoxDecoration(
                    color: creamBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7D8CC)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: selectedImage != null
                      ? Image.memory(
                          selectedImage!,
                          fit: BoxFit.cover,
                        )
                      : widget.categoryImage.isNotEmpty
                          ? Image.memory(
                              base64Decode(widget.categoryImage),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) {
                                return const Icon(
                                  Icons.broken_image_outlined,
                                  size: 54,
                                  color: pizzaOrange,
                                );
                              },
                            )
                          : const Icon(
                              Icons.image_outlined,
                              size: 54,
                              color: pizzaOrange,
                            ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: selectImage,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Change Image'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pizzaRed,
                    side: const BorderSide(color: pizzaRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: updateCategory,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Update Category'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pizzaRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

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

class _BodyCell extends StatelessWidget {
  final String text;

  const _BodyCell(this.text);

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
