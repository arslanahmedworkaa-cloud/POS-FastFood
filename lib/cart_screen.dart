import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'receipt_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ScrollController verticalController = ScrollController();

  final ScrollController horizontalController = ScrollController();

  final TextEditingController customerNameController =
      TextEditingController(text: 'Dear Customer');

  String getCurrentDate() {
    final DateTime now = DateTime.now();

    final String day = now.day.toString().padLeft(2, '0');

    final String month = now.month.toString().padLeft(2, '0');

    final String year = now.year.toString();

    return '$day-$month-$year';
  }

  Future<String> getCategoryName(
    String categoryId,
  ) async {
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

  Future<int> getNextOrderNumber() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return 1;
    }

    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('orderNumber')
          .get();

      if (!result.exists) {
        return 1;
      }

      final data = result.data();

      if (data == null) {
        return 1;
      }

      final int lastOrderNumber = int.tryParse(
            data['lastOrderNumber']?.toString() ?? '0',
          ) ??
          0;

      return lastOrderNumber + 1;
    } catch (e) {
      return 1;
    }
  }

  Future<void> deleteItem(
    String documentId,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Item'),
          content: const Text(
            'Are you sure you want to remove this item from the bill?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(documentId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Item removed from bill',
          ),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  Future<void> changeQuantity(
    String documentId,
    int currentQuantity,
    int change,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final int newQuantity = currentQuantity + change;

    try {
      if (newQuantity <= 0) {
        await deleteItem(documentId);
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(documentId)
          .update({
        'quantity': newQuantity,
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

  double calculateTotal(
    Map<String, dynamic> data,
  ) {
    final double price = double.tryParse(
          data['price']?.toString() ?? '0',
        ) ??
        0;

    final int quantity = int.tryParse(
          data['quantity']?.toString() ?? '0',
        ) ??
        0;

    return price * quantity;
  }

  Future<void> previewOrder(
    List<QueryDocumentSnapshot> cartItems,
    double grandTotal,
  ) async {
    if (cartItems.isEmpty) {
      return;
    }

    try {
      final int orderNumber = await getNextOrderNumber();

      final List<Map<String, dynamic>> orderItems = [];

      for (final doc in cartItems) {
        final data = doc.data() as Map<String, dynamic>;

        final String categoryId = data['categoryId']?.toString() ?? '';

        final String categoryName = await getCategoryName(categoryId);

        orderItems.add({
          'itemId': data['itemId']?.toString() ?? '',
          'itemName': data['itemName']?.toString() ?? '',
          'categoryId': categoryId,
          'categoryName': categoryName,
          'size': data['size']?.toString() ?? '',
          'price': data['price']?.toString() ?? '',
          'quantity': int.tryParse(
                data['quantity']?.toString() ?? '0',
              ) ??
              0,
          'total': calculateTotal(data),
        });
      }

      String customerName = customerNameController.text.trim();

      if (customerName.isEmpty) {
        customerName = 'Dear Customer';
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiptScreen(
            orderNumber: orderNumber,
            date: getCurrentDate(),
            customerName: customerName,
            orderItems: orderItems,
            grandTotal: grandTotal,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error preparing receipt: $e',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    customerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'User is not logged in',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
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

          final List<QueryDocumentSnapshot> cartItems =
              snapshot.data?.docs ?? [];

          if (cartItems.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 70,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Cart is empty',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          double grandTotal = 0;
          int totalQuantity = 0;

          for (final doc in cartItems) {
            final data = doc.data() as Map<String, dynamic>;

            grandTotal += calculateTotal(data);

            totalQuantity += int.tryParse(
                  data['quantity']?.toString() ?? '0',
                ) ??
                0;
          }

          return FutureBuilder<int>(
            future: getNextOrderNumber(),
            builder: (
              context,
              orderSnapshot,
            ) {
              final int orderNumber = orderSnapshot.data ?? 1;

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          15,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'SALES BILL',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Date',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  getCurrentDate(),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Order No.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  orderNumber.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 12,
                            ),

                            // Customer Name
                            TextField(
                              controller: customerNameController,
                              decoration: InputDecoration(
                                labelText: 'Customer Name',
                                hintText: 'Dear Customer',
                                prefixIcon: const Icon(
                                  Icons.person,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (
                          context,
                          constraints,
                        ) {
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
                                    return notification.metrics.axis ==
                                        Axis.horizontal;
                                  },
                                  child: SingleChildScrollView(
                                    controller: horizontalController,
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: 850,
                                      ),
                                      child: DataTable(
                                        headingRowHeight: 50,
                                        dataRowMinHeight: 55,
                                        dataRowMaxHeight: 65,
                                        columnSpacing: 25,
                                        columns: const [
                                          DataColumn(
                                            label: Text(
                                              'Item ID',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Category',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Item Name',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Size',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Price',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Qty',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Total',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Action',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        rows: cartItems.map(
                                          (doc) {
                                            final data = doc.data()
                                                as Map<String, dynamic>;

                                            final String itemId =
                                                data['itemId']?.toString() ??
                                                    '';

                                            final String itemName =
                                                data['itemName']?.toString() ??
                                                    '';

                                            final String categoryId =
                                                data['categoryId']
                                                        ?.toString() ??
                                                    '';

                                            final String size =
                                                data['size']?.toString() ?? '';

                                            final String price =
                                                data['price']?.toString() ?? '';

                                            final int quantity = int.tryParse(
                                                  data['quantity']
                                                          ?.toString() ??
                                                      '0',
                                                ) ??
                                                0;

                                            final double total = calculateTotal(
                                              data,
                                            );

                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(
                                                    itemId,
                                                  ),
                                                ),
                                                DataCell(
                                                  FutureBuilder<String>(
                                                    future: getCategoryName(
                                                      categoryId,
                                                    ),
                                                    builder: (
                                                      context,
                                                      categorySnapshot,
                                                    ) {
                                                      return Text(
                                                        categorySnapshot.data ??
                                                            categoryId,
                                                      );
                                                    },
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    itemName,
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    size.isEmpty ? 'N/A' : size,
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    'Rs. $price',
                                                  ),
                                                ),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.remove,
                                                          size: 18,
                                                        ),
                                                        onPressed: () {
                                                          changeQuantity(
                                                            doc.id,
                                                            quantity,
                                                            -1,
                                                          );
                                                        },
                                                      ),
                                                      Text(
                                                        quantity.toString(),
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.add,
                                                          size: 18,
                                                        ),
                                                        onPressed: () {
                                                          changeQuantity(
                                                            doc.id,
                                                            quantity,
                                                            1,
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    'Rs. ${total.toStringAsFixed(0)}',
                                                  ),
                                                ),
                                                DataCell(
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed: () {
                                                      deleteItem(
                                                        doc.id,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ).toList(),
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
                    const SizedBox(height: 12),
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          15,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Items',
                                  style: TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  totalQuantity.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Grand Total',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Rs. ${grandTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          previewOrder(
                            cartItems,
                            grandTotal,
                          );
                        },
                        icon: const Icon(
                          Icons.receipt_long,
                        ),
                        label: const Text(
                          'View Receipt',
                          style: TextStyle(
                            fontSize: 17,
                          ),
                        ),
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
