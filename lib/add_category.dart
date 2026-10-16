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

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final idController = TextEditingController();
  final nameController = TextEditingController();

  Uint8List? selectedImage;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  CollectionReference get categoriesCollection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('categories');
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

  Future<void> saveCategory() async {
    String categoryId = idController.text.trim();
    String categoryName = nameController.text.trim();

    if (categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Category ID')),
      );
      return;
    }

    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Category Name')),
      );
      return;
    }

    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Category Image')),
      );
      return;
    }

    if (currentUser == null) return;

    try {
      final existingCategory = await categoriesCollection.doc(categoryId).get();

      if (!mounted) return;

      if (existingCategory.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This Category ID already exists'),
          ),
        );
        return;
      }

      String imageBase64 = base64Encode(selectedImage!);

      await categoriesCollection.doc(categoryId).set({
        'categoryId': categoryId,
        'categoryName': categoryName,
        'categoryImage': imageBase64,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category saved successfully')),
      );

      idController.clear();
      nameController.clear();

      setState(() {
        selectedImage = null;
      });
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
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User is not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: AppBar(
        title: const Text(
          'Add Category',
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
                'Category Details',
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
                decoration: fieldDecoration('Enter Category ID'),
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
                  width: 170,
                  height: 150,
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
                      : const Icon(
                          Icons.add_photo_alternate_outlined,
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
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Select Image'),
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
                  onPressed: saveCategory,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Category'),
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
