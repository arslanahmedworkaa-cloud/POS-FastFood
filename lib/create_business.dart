import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

const Color pizzaRed = Color(0xFFD93636);
const Color pizzaOrange = Color(0xFFFF8A3D);
const Color creamBackground = Color(0xFFFFF8F1);
const Color darkText = Color(0xFF292524);

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

  Future<void> loadBusiness() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final result = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid)
          .get();

      if (!result.exists) return;

      final data = result.data();
      if (data == null || !mounted) return;

      setState(() {
        businessNameController.text = data['businessName']?.toString() ?? '';
        emailController.text = data['email']?.toString() ?? '';
        phoneController.text = data['phone']?.toString() ?? '';
        addressController.text = data['address']?.toString() ?? '';
        oldImageBase64 = data['imageUrl']?.toString();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading business: $e')),
      );
    }
  }

  Future<void> selectImage() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) return;

      final Uint8List bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        selectedImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<String?> convertImageToBase64(Uint8List bytes) async {
    try {
      final img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

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
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String? imageBase64 = oldImageBase64;

      if (selectedImageBytes != null) {
        imageBase64 = await convertImageToBase64(selectedImageBytes!);

        if (imageBase64 == null) {
          throw Exception('Unable to process image');
        }
      }

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

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business details saved successfully'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving business: $e')),
      );
    }
  }

  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: pizzaRed),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: pizzaOrange.withOpacity(0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: pizzaOrange.withOpacity(0.30)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: pizzaRed, width: 1.5),
      ),
    );
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
      backgroundColor: creamBackground,
      appBar: AppBar(
        title: const Text(
          'Business Information',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: creamBackground,
        foregroundColor: darkText,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: pizzaOrange.withOpacity(0.25),
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: selectImage,
                    child: Container(
                      width: 125,
                      height: 125,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pizzaOrange.withOpacity(0.12),
                        border: Border.all(
                          color: pizzaOrange,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: selectedImageBytes != null
                          ? Image.memory(
                              selectedImageBytes!,
                              fit: BoxFit.cover,
                            )
                          : oldImageBase64 != null && oldImageBase64!.isNotEmpty
                              ? Image.memory(
                                  base64Decode(oldImageBase64!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.add_a_photo,
                                      color: pizzaRed,
                                      size: 40,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.add_a_photo,
                                  color: pizzaRed,
                                  size: 40,
                                ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap to select business logo',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: businessNameController,
                    decoration: fieldDecoration(
                      'Business Name',
                      Icons.storefront,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: fieldDecoration(
                      'Email',
                      Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: fieldDecoration(
                      'Phone Number',
                      Icons.phone_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: fieldDecoration(
                      'Business Address',
                      Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : saveBusiness,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pizzaRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: pizzaRed.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Business Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
