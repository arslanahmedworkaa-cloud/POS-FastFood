import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'create_business.dart';
import 'login_screen.dart';
import 'categories.dart';
import 'items.dart';
import 'cart_screen.dart';
import 'sales_order.dart';
import 'sales_category.dart';
import 'sales_item.dart';
import 'find_order.dart';
import 'cancel_order.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessAddress = '';
  String businessImage = '';

  final TextEditingController searchController = TextEditingController();

  String searchText = '';

  // Category ID -> Category Name
  Map<String, String> categoryNames = {};

  @override
  void initState() {
    super.initState();
    loadBusiness();
    loadCategories();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // Search only when Search icon is pressed or Enter is pressed.
  void searchItems() {
    final String text = searchController.text.trim().toLowerCase();

    setState(() {
      searchText = text;
    });
  }

  // Load business data from Firebase
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

      if (data == null || !mounted) {
        return;
      }

      setState(() {
        businessName = data['businessName']?.toString() ?? '';
        businessEmail = data['email']?.toString() ?? '';
        businessPhone = data['phone']?.toString() ?? '';
        businessAddress = data['address']?.toString() ?? '';
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

  // Load all category names once for quick search
  Future<void> loadCategories() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .get();

      final Map<String, String> loadedCategories = {};

      for (final doc in result.docs) {
        final data = doc.data();

        loadedCategories[doc.id] = data['categoryName']?.toString() ?? doc.id;
      }

      if (!mounted) return;

      setState(() {
        categoryNames = loadedCategories;
      });
    } catch (e) {
      // Search will still work using item name and category ID.
    }
  }

  // Get category name
  Future<String> getCategoryName(String categoryId) async {
    if (categoryId.isEmpty) {
      return categoryId;
    }

    if (categoryNames.containsKey(categoryId)) {
      return categoryNames[categoryId]!;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
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
          final String name = data['categoryName']?.toString() ?? categoryId;

          categoryNames[categoryId] = name;

          return name;
        }
      }
    } catch (e) {
      return categoryId;
    }

    return categoryId;
  }

  // Get category image
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

  // Check whether an item matches the search
  bool itemMatchesSearch(Map<String, dynamic> data) {
    if (searchText.isEmpty) {
      return true;
    }

    final String itemName = data['itemName']?.toString().toLowerCase() ?? '';

    final String categoryId = data['categoryId']?.toString() ?? '';

    final String categoryName = categoryNames[categoryId]?.toLowerCase() ?? '';

    final String size = data['size']?.toString().toLowerCase() ?? '';

    return itemName.contains(searchText) ||
        categoryName.contains(searchText) ||
        categoryId.toLowerCase().contains(searchText) ||
        size.contains(searchText);
  }

  // Add selected item to cart
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

        final int oldQuantity = int.tryParse(
              existingData?['quantity']?.toString() ?? '0',
            ) ??
            0;

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

  // Show business profile image
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
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
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

  // Show category image
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
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
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

  // Get today's start and tomorrow's start
  DateTime getTodayStart() {
    final DateTime now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  DateTime getTomorrowStart() {
    return getTodayStart().add(
      const Duration(days: 1),
    );
  }

  // Calculate today's completed cash
  double calculateTodayCash(
    QuerySnapshot snapshot,
  ) {
    double cash = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      final double amount = double.tryParse(
            data['grandTotal']?.toString() ?? '0',
          ) ??
          0;

      cash += amount;
    }

    return cash;
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

    // Today's completed orders
    final todayStart = getTodayStart();
    final tomorrowStart = getTomorrowStart();

    final dailyCashStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
        )
        .where(
          'createdAt',
          isLessThan: Timestamp.fromDate(tomorrowStart),
        )
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orangeAccent,
        title: const Text('myPOS-Restaurant'),
        actions: [
          // Cart
          StreamBuilder<QuerySnapshot>(
            stream: cartStream,
            builder: (
              context,
              snapshot,
            ) {
              int cartCount = 0;

              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;

                  cartCount += int.tryParse(
                        data['quantity']?.toString() ?? '0',
                      ) ??
                      0;
                }
              }

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.shopping_cart,
                    ),
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
        width: MediaQuery.of(context).size.width * 0.60,
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
                    if (businessAddress.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        businessAddress,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Business Info:'),
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
              leading: const Icon(
                Icons.category_outlined,
              ),
              title: const Text('Categories'),
              onTap: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoriesScreen(),
                  ),
                );

                loadCategories();
              },
            ),
            ExpansionTile(
              leading: const Icon(
                Icons.point_of_sale_sharp,
              ),
              title: const Text(
                'Reports',
                style: TextStyle(fontSize: 18),
              ),
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text(
                    'Daily Sales',
                    style: TextStyle(fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SalesOrderScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.category),
                  title: const Text(
                    'Sales (Category Wise)',
                    style: TextStyle(fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SalesCategoryScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.fastfood),
                  title: const Text(
                    'Sales (Item Wise)',
                    style: TextStyle(fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SalesItemScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text(
                'Orders',
                style: TextStyle(fontSize: 18),
              ),
              children: [
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text(
                    'Find Order',
                    style: TextStyle(fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FindOrderScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.cancel_outlined,
                  ),
                  title: const Text(
                    'Cancel Order',
                    style: TextStyle(fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CancelOrderScreen(),
                      ),
                    );
                  },
                ),
              ],
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
        builder: (
          context,
          snapshot,
        ) {
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

          final allItems = snapshot.data?.docs ?? [];

          if (allItems.isEmpty) {
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

          final filteredItems = allItems.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return itemMatchesSearch(data);
          }).toList();

          return Column(
            children: [
              // Daily Cash + Search
              StreamBuilder<QuerySnapshot>(
                stream: dailyCashStream,
                builder: (
                  context,
                  snapshot,
                ) {
                  double todayCash = 0;

                  if (snapshot.hasData) {
                    todayCash = calculateTodayCash(
                      snapshot.data!,
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      10,
                      12,
                      5,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Daily Cash
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cash',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Rs. ${todayCash.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        // Search box
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search item or category...',
                              suffixIcon: searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                      ),
                                      onPressed: () {
                                        searchController.clear();

                                        setState(() {
                                          searchText = '';
                                        });
                                      },
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.search,
                                      ),
                                      onPressed: searchItems,
                                    ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),

                            // Live search while typing
                            onChanged: (value) {
                              setState(() {
                                searchText = value.trim().toLowerCase();
                              });
                            },

                            onSubmitted: (_) {
                              searchItems();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              if (searchText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filteredItems.length} item(s) found',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

              if (filteredItems.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No matching items found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(15),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.70,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final data =
                          filteredItems[index].data() as Map<String, dynamic>;

                      final String name = data['itemName']?.toString() ?? '';

                      final String category =
                          data['categoryId']?.toString() ?? '';

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
                                    future: getCategoryImage(
                                      category,
                                    ),
                                    builder: (
                                      context,
                                      imageSnapshot,
                                    ) {
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
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    FutureBuilder<String>(
                                      future: getCategoryName(
                                        category,
                                      ),
                                      builder: (
                                        context,
                                        categorySnapshot,
                                      ) {
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
                                    const SizedBox(
                                      height: 5,
                                    ),
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
                  ),
                ),
            ],
          );
        },
      ),
      backgroundColor: Colors.blueGrey,
    );
  }
}
