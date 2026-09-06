import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_business.dart';
import 'login_screen.dart';
import 'categories.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessImage = '';

  @override
  void initState() {
    super.initState();
    loadBusiness();
  }

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

      if (!mounted) return;

      setState(() {
        businessName = data['businessName']?.toString() ?? '';
        businessEmail = data['email']?.toString() ?? '';
        businessPhone = data['phone']?.toString() ?? '';
        businessImage = data['imageUrl']?.toString() ?? '';
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading business: $e'),
        ),
      );
    }
  }

  // SHOW BUSINESS IMAGE
  Widget showBusinessImage() {
    if (businessImage.isEmpty) {
      return const CircleAvatar(
        radius: 40,
        child: Icon(
          Icons.local_pizza_rounded,
          size: 40,
        ),
      );
    }

    try {
      final imageBytes = base64Decode(businessImage);

      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: Image.memory(
            imageBytes,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.broken_image,
                size: 40,
              );
            },
          ),
        ),
      );
    } catch (e) {
      return const CircleAvatar(
        radius: 40,
        child: Icon(
          Icons.broken_image,
          size: 40,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('User is not logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orangeAccent,
        title: const Text('My App'),
      ),

      drawer: Drawer(
        child: ListView(
          children: [
            // BUSINESS INFORMATION
            if (businessName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  25,
                  20,
                  20,
                ),
                child: Column(
                  children: [
                    // BUSINESS PROFILE IMAGE
                    showBusinessImage(),

                    const SizedBox(height: 15),

                    // BUSINESS NAME
                    Text(
                      businessName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 5),

                    // EMAIL
                    Text(
                      businessEmail,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 3),

                    // PHONE
                    Text(
                      businessPhone,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

            // BUSINESS DETAILS
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Business Details'),
              onTap: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateBusinessScreen(),
                  ),
                );

                loadBusiness();
              },
            ),

            // INVENTORY
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Inventory'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            // ITEMS
            ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: const Text('Items'),
              onTap: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Items feature will be added later'),
                  ),
                );
              },
            ),

            // CATEGORIES
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categories'),
              onTap: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoriesScreen(),
                  ),
                );
              },
            ),

            // LOGOUT
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();

                if (!mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),

      // HOME SCREEN
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('items')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
              ),
            );
          }

          final items = snapshot.data?.docs ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No items added yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.70,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final data = items[index].data() as Map<String, dynamic>;

              final String name = data['name']?.toString() ?? '';

              final String category = data['category']?.toString() ?? '';

              final String option = data['option']?.toString() ?? '';

              final String price = data['price']?.toString() ?? '';

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.orangeAccent,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(15),
                            topRight: Radius.circular(15),
                          ),
                        ),
                        child: const Icon(
                          Icons.fastfood,
                          size: 55,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          if (option.isNotEmpty)
                            Text(
                              option,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          const SizedBox(height: 5),
                          Text(
                            'Rs. $price',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
