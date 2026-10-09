import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final itemIdController = TextEditingController();
  final itemNameController = TextEditingController();
  final priceController = TextEditingController();

  String? selectedCategoryId;
  String selectedSize = 'N/A';

  // Gets the currently logged-in Firebase user.
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Opens this user's categories collection in Firestore.
  CollectionReference get categoriesCollection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('categories');
  }

  // Opens this user's items collection in Firestore.
  CollectionReference get itemsCollection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('items');
  }

  // Returns size options based on the selected category.
  List<String> getSizeOptions(
    List<QueryDocumentSnapshot> categories,
  ) {
    // Shows the default options when no category is selected.
    if (selectedCategoryId == null) {
      return [
        'Small',
        'Medium',
        'Large',
        'N/A',
      ];
    }

    // Finds the selected category to check its name.
    for (final category in categories) {
      final data = category.data() as Map<String, dynamic>;

      final String categoryId = data['categoryId']?.toString() ?? '';

      final String categoryName = data['categoryName']?.toString() ?? '';

      if (categoryId == selectedCategoryId) {
        final String name = categoryName.toLowerCase();

        // Cold drinks use volume-based size options.
        if (name.contains('cold drinks')) {
          return [
            'Regular',
            '500 ml',
            '1 ltr',
            '1.5 ltr',
          ];
        }

        // Hot drinks have only one size option.
        if (name.contains('hot drinks')) {
          return [
            'Regular',
          ];
        }

        break;
      }
    }

    // Uses the default options for all other categories.
    return [
      'Small',
      'Medium',
      'Large',
      'N/A',
    ];
  }

  Future<void> saveItem() async {
    // Reads the input values and removes extra spaces.
    String itemId = itemIdController.text.trim();
    String itemName = itemNameController.text.trim();
    String price = priceController.text.trim();

    // A category must be selected before saving the item.
    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Category'),
        ),
      );
      return;
    }

    if (itemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Item ID'),
        ),
      );
      return;
    }

    if (itemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Item Name'),
        ),
      );
      return;
    }

    if (price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Price'),
        ),
      );
      return;
    }

    try {
      // Checks whether an item with this ID already exists.
      final existingItem = await itemsCollection.doc(itemId).get();

      if (existingItem.exists) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This Item ID already exists'),
          ),
        );

        return;
      }

      // Saves the item details under its ID in the user's items collection.
      await itemsCollection.doc(itemId).set({
        'itemId': itemId,
        'itemName': itemName,
        'categoryId': selectedCategoryId,
        'size': selectedSize,
        'price': price,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item saved successfully'),
        ),
      );

      // Clears the fields after the item is saved.
      itemIdController.clear();
      itemNameController.clear();
      priceController.clear();

      // Resets the category and size selections for the next item.
      setState(() {
        selectedCategoryId = null;
        selectedSize = 'N/A';
      });
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
    // Releases the controllers when this screen is removed.
    itemIdController.dispose();
    itemNameController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prevents using the user's Firestore collections when logged out.
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('User is not logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
        backgroundColor: Colors.orangeAccent,
      ),
      // Loads categories and updates the dropdown when Firestore changes.
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

          final categories = snapshot.data?.docs ?? [];

          // Calculates the size choices for the currently selected category.
          final List<String> sizeOptions = getSizeOptions(categories);

          return SingleChildScrollView(
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
                            'Category',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: DropdownButtonFormField<String>(
                            value: selectedCategoryId,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Select Category',
                            ),
                            // Uses Firestore categories as dropdown choices.
                            items: categories.map((category) {
                              final data =
                                  category.data() as Map<String, dynamic>;

                              String id = data['categoryId'] ?? '';

                              String name = data['categoryName'] ?? '';

                              return DropdownMenuItem<String>(
                                value: id,
                                child: Text('$id $name'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCategoryId = value;

                                // Finds the selected category's name to choose its default size.
                                String categoryName = '';

                                for (final category in categories) {
                                  final data =
                                      category.data() as Map<String, dynamic>;

                                  final String id =
                                      data['categoryId']?.toString() ?? '';

                                  if (id == value) {
                                    categoryName = data['categoryName']
                                            ?.toString()
                                            .toLowerCase() ??
                                        '';
                                    break;
                                  }
                                }

                                // Sets the initial size for drinks and other categories.
                                if (categoryName.contains('cold drinks') ||
                                    categoryName.contains('hot drinks')) {
                                  selectedSize = 'Regular';
                                } else {
                                  selectedSize = 'N/A';
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Item ID',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: itemIdController,
                            decoration: const InputDecoration(
                              hintText: 'Enter Item ID',
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
                            'Item Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: itemNameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter Item Name',
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
                            'Size',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: DropdownButtonFormField<String>(
                            // Keeps the selected size valid for the available options.
                            value: sizeOptions.contains(selectedSize)
                                ? selectedSize
                                : sizeOptions.first,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: sizeOptions.map(
                              (size) {
                                return DropdownMenuItem<String>(
                                  value: size,
                                  child: Text(size),
                                );
                              },
                            ).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSize = value ?? sizeOptions.first;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Price',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Enter Price',
                              border: OutlineInputBorder(),
                            ),
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
                    onPressed: saveItem,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      backgroundColor: const Color(0xffc6d1d7),
    );
  }
}
