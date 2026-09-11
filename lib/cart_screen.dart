import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

  String getCurrentDate() {
    final DateTime now = DateTime.now();

    final String day = now.day.toString().padLeft(2, '0');
    final String month = now.month.toString().padLeft(2, '0');
    final String year = now.year.toString();

    return '$day-$month-$year';
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

  Future<int> getNextOrderNumber() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return 1;
    }

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

    final int lastOrderNumber =
        int.tryParse(data['lastOrderNumber']?.toString() ?? '1') ?? 1;

    return lastOrderNumber + 1;
  }

  Future<void> deleteItem(String itemId) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final confirm = await showDialog<bool>(
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
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
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
          .doc(itemId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item removed from bill'),
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

  double calculateTotal(Map<String, dynamic> data) {
    final double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;

    final int quantity = int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;

    return price * quantity;
  }

  Future<void> confirmOrder(
    List<QueryDocumentSnapshot> cartItems,
    double grandTotal,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    if (cartItems.isEmpty) {
      return;
    }

    try {
      final int orderNumber = await getNextOrderNumber();

      final orderReference = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .doc(orderNumber.toString());

      final List<Map<String, dynamic>> orderItems = [];

      for (final doc in cartItems) {
        final data = doc.data() as Map<String, dynamic>;

        orderItems.add({
          'itemId': data['itemId']?.toString() ?? '',
          'itemName': data['itemName']?.toString() ?? '',
          'categoryId': data['categoryId']?.toString() ?? '',
          'size': data['size']?.toString() ?? '',
          'price': data['price']?.toString() ?? '',
          'quantity': data['quantity'] ?? 0,
          'total': calculateTotal(data),
        });
      }

      await orderReference.set({
        'orderNo': orderNumber,
        'date': getCurrentDate(),
        'items': orderItems,
        'grandTotal': grandTotal,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('orderNumber')
          .set({
        'lastOrderNumber': orderNumber,
      });

      for (final doc in cartItems) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .doc(doc.id)
            .delete();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order No. $orderNumber confirmed successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming order: $e'),
        ),
      );
    }
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
        title: const Text('Bill'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
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

          final cartItems = snapshot.data?.docs ?? [];

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

            totalQuantity +=
                int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
          }

          return FutureBuilder<int>(
            future: getNextOrderNumber(),
            builder: (context, orderSnapshot) {
              final int orderNumber = orderSnapshot.data ?? 1;

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          children: [
                            const Text(
                              'SALES BILL',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Date',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(getCurrentDate()),
                              ],
                            ),
                            const SizedBox(height: 8),
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
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
                                        rows: cartItems.map((doc) {
                                          final data = doc.data()
                                              as Map<String, dynamic>;

                                          final String itemId =
                                              data['itemId']?.toString() ?? '';

                                          final String itemName =
                                              data['itemName']?.toString() ??
                                                  '';

                                          final String categoryId =
                                              data['categoryId']?.toString() ??
                                                  '';

                                          final String size =
                                              data['size']?.toString() ?? '';

                                          final String price =
                                              data['price']?.toString() ?? '';

                                          final int quantity = int.tryParse(
                                                data['quantity']?.toString() ??
                                                    '0',
                                              ) ??
                                              0;

                                          final double total =
                                              calculateTotal(data);

                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(itemId),
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
                                                Text(itemName),
                                              ),
                                              DataCell(
                                                Text(
                                                  size.isEmpty ? 'N/A' : size,
                                                ),
                                              ),
                                              DataCell(
                                                Text('Rs. $price'),
                                              ),
                                              DataCell(
                                                Text(quantity.toString()),
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
                                                    deleteItem(itemId);
                                                  },
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
                    const SizedBox(height: 12),
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(15),
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
                          confirmOrder(
                            cartItems,
                            grandTotal,
                          );
                        },
                        icon: const Icon(
                          Icons.check_circle_outline,
                        ),
                        label: const Text(
                          'Confirm Order',
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
