import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Restaurant theme colors.
const Color pizzaRed = Color(0xFFD93636);
const Color pizzaOrange = Color(0xFFFF8A3D);
const Color creamBackground = Color(0xFFFFF8F1);
const Color darkText = Color(0xFF292524);

class EditItemScreen extends StatefulWidget {
  const EditItemScreen({super.key});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

  // Gets the category name using its saved category ID.
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

  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: creamBackground,
        body: Center(child: Text('User is not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: AppBar(
        title: const Text(
          'Edit Items',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: pizzaRed,
        foregroundColor: Colors.white,
        elevation: 0,
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
              child: CircularProgressIndicator(color: pizzaRed),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final items = snapshot.data?.docs ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No items added yet',
                style: TextStyle(color: darkText),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    child: Scrollbar(
                      controller: verticalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: SingleChildScrollView(
                        controller: verticalController,
                        scrollDirection: Axis.vertical,
                        child: Scrollbar(
                          controller: horizontalController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          notificationPredicate: (notification) {
                            return notification.metrics.axis == Axis.horizontal;
                          },
                          child: SingleChildScrollView(
                            controller: horizontalController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 700,
                              ),
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                  const Color(0xFFFFF1E7),
                                ),
                                dataRowMinHeight: 58,
                                dataRowMaxHeight: 70,
                                columnSpacing: 25,
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Item ID',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: darkText,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Item Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: darkText,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Category',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: darkText,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Size',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: darkText,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Price',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: darkText,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Action',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: darkText,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: items.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;

                                  final String itemId =
                                      data['itemId']?.toString() ?? '';
                                  final String itemName =
                                      data['itemName']?.toString() ?? '';
                                  final String categoryId =
                                      data['categoryId']?.toString() ?? '';
                                  final String size =
                                      data['size']?.toString() ?? '';
                                  final String price =
                                      data['price']?.toString() ?? '';

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(itemId)),
                                      DataCell(Text(itemName)),
                                      DataCell(
                                        FutureBuilder<String>(
                                          future: getCategoryName(categoryId),
                                          builder: (context, categorySnapshot) {
                                            return Text(
                                              categorySnapshot.data ??
                                                  categoryId,
                                            );
                                          },
                                        ),
                                      ),
                                      DataCell(Text(size)),
                                      DataCell(Text(price)),
                                      DataCell(
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    EditItemForm(
                                                  itemId: itemId,
                                                  itemName: itemName,
                                                  categoryId: categoryId,
                                                  size: size,
                                                  price: price,
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: pizzaOrange,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text('Edit'),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class EditItemForm extends StatefulWidget {
  final String itemId;
  final String itemName;
  final String categoryId;
  final String size;
  final String price;

  const EditItemForm({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.categoryId,
    required this.size,
    required this.price,
  });

  @override
  State<EditItemForm> createState() => _EditItemFormState();
}

class _EditItemFormState extends State<EditItemForm> {
  late TextEditingController itemNameController;
  late TextEditingController priceController;
  late TextEditingController itemIdController;

  String? selectedCategory;
  String? selectedSize;

  List<Map<String, String>> categories = [];

  @override
  void initState() {
    super.initState();

    itemNameController = TextEditingController(text: widget.itemName);
    priceController = TextEditingController(text: widget.price);
    itemIdController = TextEditingController(text: widget.itemId);

    selectedCategory = widget.categoryId;
    selectedSize = widget.size;

    loadCategories();
  }

  // Loads category IDs and names from the current user's collection.
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

      final List<Map<String, String>> loadedCategories = [];

      for (final doc in result.docs) {
        final data = doc.data();

        final String id = data['categoryId']?.toString() ?? '';
        final String name = data['categoryName']?.toString() ?? '';

        if (id.isNotEmpty && name.isNotEmpty) {
          loadedCategories.add({
            'id': id,
            'name': name,
          });
        }
      }

      if (!mounted) return;

      setState(() {
        categories = loadedCategories;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
    }
  }

  // Saves the edited item details to Firestore.
  Future<void> updateItem() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    if (selectedCategory == null || selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Category')),
      );
      return;
    }

    if (itemNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Item Name')),
      );
      return;
    }

    if (selectedSize == null || selectedSize!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Size')),
      );
      return;
    }

    if (priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Price')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('items')
          .doc(widget.itemId)
          .update({
        'itemName': itemNameController.text.trim(),
        'categoryId': selectedCategory,
        'size': selectedSize,
        'price': priceController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated successfully')),
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
    itemNameController.dispose();
    priceController.dispose();
    itemIdController.dispose();
    super.dispose();
  }

  // Gives edit form fields a matching rounded style.
  InputDecoration fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
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
        borderSide: const BorderSide(color: pizzaRed, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBackground,
      appBar: AppBar(
        title: const Text(
          'Edit Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: pizzaRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.edit_note,
                      size: 42,
                      color: pizzaRed,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Update Menu Item',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      readOnly: true,
                      controller: itemIdController,
                      decoration: fieldDecoration('Item ID'),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: categories.any(
                        (category) => category['id'] == selectedCategory,
                      )
                          ? selectedCategory
                          : null,
                      decoration: fieldDecoration('Category'),
                      items: categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['id'],
                          child: Text(
                            '${category['id']} ${category['name']}',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: itemNameController,
                      decoration: fieldDecoration('Item Name'),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: const ['Small', 'Medium', 'Large', 'N/A']
                              .contains(selectedSize)
                          ? selectedSize
                          : 'N/A',
                      decoration: fieldDecoration('Size'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Small',
                          child: Text('Small'),
                        ),
                        DropdownMenuItem(
                          value: 'Medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(
                          value: 'Large',
                          child: Text('Large'),
                        ),
                        DropdownMenuItem(
                          value: 'N/A',
                          child: Text('N/A'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedSize = value;
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: fieldDecoration('Price'),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: updateItem,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text(
                          'Update Item',
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
      ),
    );
  }
}
