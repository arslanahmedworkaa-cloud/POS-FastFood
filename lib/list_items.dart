import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Restaurant theme colors.
const Color pizzaRed = Color(0xFFD93636);
const Color pizzaOrange = Color(0xFFFF8A3D);
const Color creamBackground = Color(0xFFFFF8F1);
const Color darkText = Color(0xFF292524);

class ListItemsScreen extends StatefulWidget {
  const ListItemsScreen({super.key});

  @override
  State<ListItemsScreen> createState() => _ListItemsScreenState();
}

class _ListItemsScreenState extends State<ListItemsScreen> {
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
    // Releases both scroll controllers when this screen closes.
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
        body: Center(
          child: Text('User is not logged in'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: creamBackground,
      appBar: AppBar(
        title: const Text(
          'List Items',
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 55,
                    color: pizzaOrange,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No items added yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ],
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
                                      DataCell(
                                        Text(
                                          price,
                                          style: const TextStyle(
                                            color: pizzaRed,
                                            fontWeight: FontWeight.bold,
                                          ),
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
