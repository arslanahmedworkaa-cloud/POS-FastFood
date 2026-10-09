import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class CreateBusinessScreen extends StatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  State<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends State<CreateBusinessScreen> {
  final businessNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();

  Uint8List? selectedImageBytes;

  String? oldImageBase64;

  bool isLoading = false;

  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadBusiness();
  }

  // Load existing business details
  Future<void> loadBusiness() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final result = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid)
          .get();

      if (!result.exists) {
        return;
      }

      final data = result.data();

      if (data == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        businessNameController.text = data['businessName']?.toString() ?? '';

        emailController.text = data['email']?.toString() ?? '';

        phoneController.text = data['phone']?.toString() ?? '';

        addressController.text = data['address']?.toString() ?? '';

        oldImageBase64 = data['imageUrl']?.toString();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading business: $e',
          ),
        ),
      );
    }
  }

  // Select business profile image
  Future<void> selectImage() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) {
        return;
      }

      final Uint8List bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        selectedImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error selecting image: $e',
          ),
        ),
      );
    }
  }

  // Compress image and convert it to Base64
  Future<String?> convertImageToBase64(
    Uint8List bytes,
  ) async {
    try {
      final img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        return null;
      }

      final img.Image resizedImage = img.copyResize(
        originalImage,
        width: 400,
      );

      final List<int> compressedImage = img.encodeJpg(
        resizedImage,
        quality: 60,
      );

      return base64Encode(compressedImage);
    } catch (e) {
      return null;
    }
  }

  // Save business details
  Future<void> saveBusiness() async {
    final String businessName = businessNameController.text.trim();

    final String email = emailController.text.trim();

    final String phone = phoneController.text.trim();

    final String address = addressController.text.trim();

    if (businessName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all fields',
          ),
        ),
      );

      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please login first',
          ),
        ),
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String? imageBase64 = oldImageBase64;

      // Convert selected image to Base64
      if (selectedImageBytes != null) {
        imageBase64 = await convertImageToBase64(
          selectedImageBytes!,
        );

        if (imageBase64 == null) {
          throw Exception(
            'Unable to process image',
          );
        }
      }

      // Save business details to Firestore
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid)
          .set({
        'businessName': businessName,
        'email': email,
        'phone': phone,
        'address': address,
        'imageUrl': imageBase64 ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Business details saved successfully',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving business: $e',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    businessNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Business Info:',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Business profile image
            GestureDetector(
              onTap: selectImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                ),
                clipBehavior: Clip.antiAlias,
                child: selectedImageBytes != null
                    ? Image.memory(
                        selectedImageBytes!,
                        fit: BoxFit.cover,
                      )
                    : oldImageBase64 != null && oldImageBase64!.isNotEmpty
                        ? Image.memory(
                            base64Decode(
                              oldImageBase64!,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.add_a_photo,
                                size: 40,
                              );
                            },
                          )
                        : const Icon(
                            Icons.add_a_photo,
                            size: 40,
                          ),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Tap to select profile image',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 25),

            // Business name
            TextField(
              controller: businessNameController,
              decoration: const InputDecoration(
                labelText: 'Business Name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            // Email
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            // Phone number
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            // Business address
            TextField(
              controller: addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveBusiness,
                child: isLoading
                    ? const SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(),
                      )
                    : const Text(
                        'Save Business',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xffc6d1d7),
    );
  }
}
