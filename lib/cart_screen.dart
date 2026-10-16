import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'receipt_screen.dart';

// Shared restaurant colors used to keep the bill screen consistent.
const Color pizzaRed = Color(0xFFD93636);
const Color pizzaOrange = Color(0xFFFF8A3D);
const Color creamBackground = Color(0xFFFFF8F1);
const Color darkText = Color(0xFF292524);

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

  // Get the current date in day-month-year format.
  String getCurrentDate() {
    final DateTime now = DateTime.now();
    final String day = now.day.toString().padLeft(2, '0');
    final String month = now.month.toString().padLeft(2, '0');
    final String year = now.year.toString();

    return '$day-$month-$year';
  }

  // Get a category name from Firestore using its category ID.
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

  // Find the next order number without changing the saved number yet.
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

  // Ask before removing an item from the bill.
  Future<void> deleteItem(String documentId) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Remove Item',
            style: TextStyle(
              color: pizzaRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to remove this item from the bill?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: darkText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pizzaRed,
                foregroundColor: Colors.white,
              ),
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
          .doc(documentId)
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
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Increase or decrease an item's quantity in the cart.
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
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Calculate an item's total price from price multiplied by quantity.
  double calculateTotal(Map<String, dynamic> data) {
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

  // Prepare the order details and open the receipt preview.
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
        SnackBar(content: Text('Error preparing receipt: $e')),
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
          'Bill',
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
            .collection('cart')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: pizzaRed),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
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
                    color: pizzaOrange,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Cart is empty',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: darkText,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Add items to prepare a bill',
                    style: TextStyle(color: Colors.grey),
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
            builder: (context, orderSnapshot) {
              final int orderNumber = orderSnapshot.data ?? 1;

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Bill heading and customer details.
                    Card(
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: pizzaRed.withOpacity(0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          children: [
                            const Text(
                              'SALES BILL',
                              style: TextStyle(
                                fontSize: 23,
                                color: pizzaRed,
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
                                    color: darkText,
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
                                    color: darkText,
                                  ),
                                ),
                                Text(
                                  orderNumber.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: pizzaRed,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: customerNameController,
                              decoration: InputDecoration(
                                labelText: 'Customer Name',
                                hintText: 'Dear Customer',
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                  color: pizzaRed,
                                ),
                                filled: true,
                                fillColor: creamBackground,
                                labelStyle: const TextStyle(color: darkText),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: pizzaOrange.withOpacity(0.45),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: pizzaRed,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Scrollable bill table for smaller screens.
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
                                        headingRowColor:
                                            MaterialStateProperty.all(
                                          creamBackground,
                                        ),
                                        headingTextStyle: const TextStyle(
                                          color: pizzaRed,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        dataTextStyle: const TextStyle(
                                          color: darkText,
                                        ),
                                        headingRowHeight: 50,
                                        dataRowMinHeight: 55,
                                        dataRowMaxHeight: 65,
                                        columnSpacing: 25,
                                        columns: const [
                                          DataColumn(label: Text('Item ID')),
                                          DataColumn(label: Text('Category')),
                                          DataColumn(label: Text('Item Name')),
                                          DataColumn(label: Text('Size')),
                                          DataColumn(label: Text('Price')),
                                          DataColumn(label: Text('Qty')),
                                          DataColumn(label: Text('Total')),
                                          DataColumn(label: Text('Action')),
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
                                              DataCell(Text(itemId)),
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
                                              DataCell(Text(itemName)),
                                              DataCell(
                                                Text(
                                                  size.isEmpty ? 'N/A' : size,
                                                ),
                                              ),
                                              DataCell(Text('Rs. $price')),
                                              DataCell(
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip:
                                                          'Decrease quantity',
                                                      color: pizzaRed,
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
                                                      tooltip:
                                                          'Increase quantity',
                                                      color: pizzaRed,
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
                                                  tooltip: 'Remove item',
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: pizzaRed,
                                                  ),
                                                  onPressed: () {
                                                    deleteItem(doc.id);
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

                    // Summary of quantity and bill amount.
                    Card(
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: pizzaRed.withOpacity(0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                                    color: darkText,
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
                                    color: darkText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Rs. ${grandTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: pizzaRed,
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

                    // Open the receipt preview before printing.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pizzaRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          previewOrder(cartItems, grandTotal);
                        },
                        icon: const Icon(Icons.receipt_long),
                        label: const Text(
                          'View Receipt',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
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
