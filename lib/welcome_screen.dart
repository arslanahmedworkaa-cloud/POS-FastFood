import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'create_business.dart';
import 'login_screen.dart';
import 'categories.dart';
import 'items.dart';
import 'cart_screen.dart';

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

  Future<String> getCategoryName(String categoryId) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || categoryId.isEmpty) {
      return categoryId;
    }

    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId)
          .get();

      if (result.exists) {
        final data = result.data();

        if (data != null) {
          return data['categoryName']?.toString() ?? categoryId;
        }
      }
    } catch (e) {
      return categoryId;
    }

    return categoryId;
  }

  Future<String> getCategoryImage(String categoryId) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || categoryId.isEmpty) {
      return '';
    }

    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId)
          .get();

      if (result.exists) {
        final data = result.data();

        if (data != null) {
          return data['categoryImage']?.toString() ?? '';
        }
      }
    } catch (e) {
      return '';
    }

    return '';
  }

  Future<void> addToCart(Map<String, dynamic> data) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final String itemId = data['itemId']?.toString() ?? '';
    final String itemName = data['itemName']?.toString() ?? '';
    final String categoryId = data['categoryId']?.toString() ?? '';
    final String size = data['size']?.toString() ?? '';
    final String price = data['price']?.toString() ?? '';

    if (itemId.isEmpty) {
      return;
    }

    try {
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(itemId);

      final existing = await cartRef.get();

      if (existing.exists) {
        final existingData = existing.data();

        final int oldQuantity =
            int.tryParse(existingData?['quantity']?.toString() ?? '0') ?? 0;

        await cartRef.update({
          'quantity': oldQuantity + 1,
        });
      } else {
        await cartRef.set({
          'itemId': itemId,
          'itemName': itemName,
          'categoryId': categoryId,
          'size': size,
          'price': price,
          'quantity': 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item added to cart'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to cart: $e'),
        ),
      );
    }
  }

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
        backgroundColor: Colors.grey,
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

  Widget showCategoryImage(String image) {
    if (image.isEmpty) {
      return const Icon(
        Icons.fastfood,
        size: 55,
        color: Colors.white,
      );
    }

    try {
      final imageBytes = base64Decode(image);

      return Image.memory(
        imageBytes,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.fastfood,
            size: 55,
            color: Colors.white,
          );
        },
      );
    } catch (e) {
      return const Icon(
        Icons.fastfood,
        size: 55,
        color: Colors.white,
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

    final cartStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orangeAccent,
        title: const Text('My App'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: cartStream,
            builder: (context, snapshot) {
              int cartCount = 0;

              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;

                  cartCount +=
                      int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
                }
              }

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CartScreen(),
                        ),
                      );
                    },
                  ),
                  if (cartCount > 0)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          cartCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
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
                    showBusinessImage(),
                    const SizedBox(height: 15),
                    Text(
                      businessName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      businessEmail,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 3),
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
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Inventory'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: const Text('Items'),
              onTap: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ItemsScreen(),
                  ),
                );
              },
            ),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('items')
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

              final String name = data['itemName']?.toString() ?? '';
              final String category = data['categoryId']?.toString() ?? '';
              final String size = data['size']?.toString() ?? '';
              final String price = data['price']?.toString() ?? '';

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () {
                    addToCart(data);
                  },
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
                          child: FutureBuilder<String>(
                            future: getCategoryImage(category),
                            builder: (context, imageSnapshot) {
                              if (imageSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                );
                              }

                              return showCategoryImage(
                                imageSnapshot.data ?? '',
                              );
                            },
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
                            FutureBuilder<String>(
                              future: getCategoryName(category),
                              builder: (context, categorySnapshot) {
                                final categoryName =
                                    categorySnapshot.data ?? category;

                                return Text(
                                  'Category: $categoryName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                            if (size.isNotEmpty)
                              Text(
                                'Size: $size',
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
                ),
              );
            },
          );
        },
      ),
      backgroundColor: Colors.blueGrey,
    );
  }
}
