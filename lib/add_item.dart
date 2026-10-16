import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Restaurant theme colors used on this screen.
const Color pizzaRed = Color(0xFFD93636);
const Color pizzaOrange = Color(0xFFFF8A3D);
const Color creamBackground = Color(0xFFFFF8F1);
const Color darkText = Color(0xFF292524);

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
    if (selectedCategoryId == null) {
      return ['Small', 'Medium', 'Large', 'N/A'];
    }

    for (final category in categories) {
      final data = category.data() as Map<String, dynamic>;
      final String categoryId = data['categoryId']?.toString() ?? '';
      final String categoryName = data['categoryName']?.toString() ?? '';

      if (categoryId == selectedCategoryId) {
        final String name = categoryName.toLowerCase();

        // Cold drinks use volume-based size options.
        if (name.contains('cold drinks')) {
          return ['Regular', '500 ml', '1 ltr', '1.5 ltr'];
        }

        // Hot drinks have only one size option.
        if (name.contains('hot drinks')) {
          return ['Regular'];
        }

        break;
      }
    }

    // Uses the default options for all other categories.
    return ['Small', 'Medium', 'Large', 'N/A'];
  }

  // Gives text fields a consistent rounded restaurant-theme style.
  InputDecoration fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9DCD1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9DCD1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: pizzaRed,
          width: 1.5,
        ),
      ),
    );
  }

  Future<void> saveItem() async {
    String itemId = itemIdController.text.trim();
    String itemName = itemNameController.text.trim();
    String price = priceController.text.trim();

    // A category must be selected before saving the item.
    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Category')),
      );
      return;
    }

    if (itemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Item ID')),
      );
      return;
    }

    if (itemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Item Name')),
      );
      return;
    }

    if (price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Price')),
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
        const SnackBar(content: Text('Item saved successfully')),
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
        SnackBar(content: Text('Error: $e')),
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
        backgroundColor: creamBackground,
        body: Center(
          child: Text('User is not logged in'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: AppBar(
        title: const Text(
          'Add Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: pizzaRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // Loads categories and updates the dropdown when Firestore changes.
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

          final categories = snapshot.data?.docs ?? [];
          final List<String> sizeOptions = getSizeOptions(categories);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Card(
                  color: Colors.white,
                  elevation: 3,
                  shadowColor: pizzaOrange.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 42,
                          color: pizzaRed,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add a Menu Item',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: darkText,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Table(
                          border: TableBorder.all(
                            color: const Color(0xFFE9DCD1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(1),
                            1: FlexColumnWidth(2),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF1E7),
                              ),
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Category',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: darkText,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: DropdownButtonFormField<String>(
                                    value: selectedCategoryId,

                                    // Fixes overflow by using the available
                                    // width inside the table cell.
                                    isExpanded: true,

                                    decoration:
                                        fieldDecoration('Select Category'),
                                    items: categories.map((category) {
                                      final data = category.data()
                                          as Map<String, dynamic>;
                                      String id = data['categoryId'] ?? '';
                                      String name = data['categoryName'] ?? '';

                                      return DropdownMenuItem<String>(
                                        value: id,

                                        // Long category names are shortened
                                        // visually instead of overflowing.
                                        child: Text(
                                          '$id $name',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedCategoryId = value;

                                        // Finds the category name to select its default size.
                                        String categoryName = '';

                                        for (final category in categories) {
                                          final data = category.data()
                                              as Map<String, dynamic>;
                                          final String id =
                                              data['categoryId']?.toString() ??
                                                  '';

                                          if (id == value) {
                                            categoryName = data['categoryName']
                                                    ?.toString()
                                                    .toLowerCase() ??
                                                '';
                                            break;
                                          }
                                        }

                                        // Keeps the original default-size behavior.
                                        if (categoryName
                                                .contains('cold drinks') ||
                                            categoryName
                                                .contains('hot drinks')) {
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
                                      color: darkText,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: TextField(
                                    controller: itemIdController,
                                    decoration:
                                        fieldDecoration('Enter Item ID'),
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
                                      color: darkText,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: TextField(
                                    controller: itemNameController,
                                    decoration:
                                        fieldDecoration('Enter Item Name'),
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
                                      color: darkText,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: DropdownButtonFormField<String>(
                                    value: sizeOptions.contains(selectedSize)
                                        ? selectedSize
                                        : sizeOptions.first,
                                    decoration: fieldDecoration('Select Size'),
                                    items: sizeOptions.map((size) {
                                      return DropdownMenuItem<String>(
                                        value: size,
                                        child: Text(size),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedSize =
                                            value ?? sizeOptions.first;
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
                                      color: darkText,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: TextField(
                                    controller: priceController,
                                    keyboardType: TextInputType.number,
                                    decoration: fieldDecoration('Enter Price'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: saveItem,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text(
                              'Save Item',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pizzaRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
