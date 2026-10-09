import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final idController = TextEditingController();
  final nameController = TextEditingController();

  // Stores the selected image as bytes in memory until the category is saved.
  Uint8List? selectedImage;

  // Gets the currently logged-in Firebase user.
  // Returns null if no user is logged in.
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Provides access to the current user's own categories collection in Firestore.
  // Each user's categories are stored separately using their UID.
  CollectionReference get categoriesCollection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('categories');
  }

  Future<void> selectImage() async {
    final ImagePicker picker = ImagePicker();

    // Opens the device gallery and lets the user select an image.
    // Limits the image dimensions and quality to reduce its size.
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 50,
    );

    // Stops if the user cancels image selection.
    if (image == null) {
      return;
    }

    // Reads the selected image as bytes so it can be displayed and saved.
    final bytes = await image.readAsBytes();

    // Updates the selected image and rebuilds the screen to show its preview.
    setState(() {
      selectedImage = bytes;
    });
  }

  // Validates the category details and saves the category in Firestore.
  Future<void> saveCategory() async {
    // Reads the entered values and removes spaces from their beginning and end.
    String categoryId = idController.text.trim();
    String categoryName = nameController.text.trim();

    // Requires a category ID before continuing.
    if (categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Category ID'),
        ),
      );
      return;
    }

    // Requires a category name before continuing.
    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Category Name'),
        ),
      );
      return;
    }

    // Requires an image before saving the category.
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Category Image'),
        ),
      );
      return;
    }

    // Stops the operation if there is no logged-in user.
    if (currentUser == null) {
      return;
    }

    try {
      // Checks whether a category with this ID already exists.
      // The category ID is also used as the Firestore document ID.
      final existingCategory = await categoriesCollection.doc(categoryId).get();

      // Prevents saving another category with the same ID.
      if (existingCategory.exists) {
        // Checks that the screen is still active before using its context.
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This Category ID already exists'),
          ),
        );

        return;
      }

      // Converts the selected image bytes into a Base64 string.
      // This allows the image data to be stored directly in a Firestore document.
      String imageBase64 = base64Encode(selectedImage!);

      // Saves the category details and image in the current user's categories collection.
      // FieldValue.serverTimestamp() records the time according to the server.
      await categoriesCollection.doc(categoryId).set({
        'categoryId': categoryId,
        'categoryName': categoryName,
        'categoryImage': imageBase64,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Prevents using the screen's context if the screen was closed during saving.
      if (!mounted) return;

      // Confirms that the category has been saved successfully.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category saved successfully'),
        ),
      );

      // Clears the input fields after a successful save.
      idController.clear();
      nameController.clear();

      // Removes the selected image preview and updates the screen.
      setState(() {
        selectedImage = null;
      });
    } catch (e) {
      // Checks whether the screen is still active before showing an error.
      if (!mounted) return;

      // Displays an error if checking or saving the category fails.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Releases the text controllers when this screen is removed.
    // This helps prevent unnecessary resource usage.
    idController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prevents showing the category form when no user is logged in.
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('User is not logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Category'),
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
                        decoration: const InputDecoration(
                          hintText: 'Enter Category ID',
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
                          hintText: 'Enter Category Name',
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
                          // Shows the selected image, or a placeholder if none is selected.
                          if (selectedImage != null)
                            Image.memory(
                              selectedImage!,
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
                            // Opens the gallery selection process.
                            onPressed: selectImage,
                            child: const Text('Select Image'),
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
                // Validates the entered details and saves the category.
                onPressed: saveCategory,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Color(0xffc6d1d7),
    );
  }
}
