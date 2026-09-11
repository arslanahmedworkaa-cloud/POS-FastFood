import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditItemScreen extends StatefulWidget {
  const EditItemScreen({super.key});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

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
        body: Center(
          child: Text('User is not logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Items'),
        backgroundColor: Colors.orangeAccent,
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
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final items = snapshot.data?.docs ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Text('No items added yet'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(10),
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
                              columnSpacing: 25,
                              columns: const [
                                DataColumn(label: Text('Item ID')),
                                DataColumn(label: Text('Item Name')),
                                DataColumn(label: Text('Category')),
                                DataColumn(label: Text('Size')),
                                DataColumn(label: Text('Price')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: items.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;

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
                                            categorySnapshot.data ?? categoryId,
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

  String? selectedCategory;
  String? selectedSize;

  List<Map<String, String>> categories = [];

  @override
  void initState() {
    super.initState();

    itemNameController = TextEditingController(text: widget.itemName);

    priceController = TextEditingController(text: widget.price);

    selectedCategory = widget.categoryId;
    selectedSize = widget.size;

    loadCategories();
  }

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
        SnackBar(
          content: Text('Error loading categories: $e'),
        ),
      );
    }
  }

  Future<void> updateItem() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    if (selectedCategory == null || selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Category'),
        ),
      );
      return;
    }

    if (itemNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Item Name'),
        ),
      );
      return;
    }

    if (selectedSize == null || selectedSize!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Size'),
        ),
      );
      return;
    }

    if (priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Price'),
        ),
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
        const SnackBar(
          content: Text('Item updated successfully'),
        ),
      );

      Navigator.pop(context);
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
    itemNameController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Item'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              readOnly: true,
              controller: TextEditingController(
                text: widget.itemId,
              ),
              decoration: const InputDecoration(
                labelText: 'Item ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
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
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedSize,
              decoration: const InputDecoration(
                labelText: 'Size',
                border: OutlineInputBorder(),
              ),
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
              decoration: const InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: updateItem,
                child: const Text('Update'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
