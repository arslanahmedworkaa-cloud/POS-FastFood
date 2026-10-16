import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'receipt_screen.dart';

// Colors used to keep the POS screens consistent.
const Color pizzaRed = Color(0xFFD93636);
const Color pizzaOrange = Color(0xFFFF8A3D);
const Color creamBackground = Color(0xFFFFF8F1);
const Color darkText = Color(0xFF292524);

class FindOrderScreen extends StatefulWidget {
  const FindOrderScreen({super.key});

  @override
  State<FindOrderScreen> createState() => _FindOrderScreenState();
}

class _FindOrderScreenState extends State<FindOrderScreen> {
  final TextEditingController orderController = TextEditingController();

  List<QueryDocumentSnapshot> allOrders = [];
  List<QueryDocumentSnapshot> displayedOrders = [];

  bool isLoading = true;
  bool hasSearched = false;

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  @override
  void dispose() {
    orderController.dispose();
    super.dispose();
  }

  // Load all saved orders from Firebase.
  Future<void> loadOrders() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .get();

      final orders = result.docs.toList();

      // Keep orders sorted by their numeric document IDs.
      orders.sort((a, b) {
        final int aNumber = int.tryParse(a.id) ?? 0;
        final int bNumber = int.tryParse(b.id) ?? 0;
        return aNumber.compareTo(bNumber);
      });

      if (!mounted) return;

      setState(() {
        allOrders = orders;
        displayedOrders = orders;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading orders: $e')),
      );
    }
  }

  // Search for an order by its document ID.
  void searchOrder() {
    final String searchText = orderController.text.trim();

    if (searchText.isEmpty) {
      setState(() {
        displayedOrders = allOrders;
        hasSearched = false;
      });
      return;
    }

    final List<QueryDocumentSnapshot> results = allOrders.where((order) {
      return order.id == searchText;
    }).toList();

    setState(() {
      displayedOrders = results;
      hasSearched = true;
    });
  }

  // Clear the search and show all orders again.
  void showAllOrders() {
    orderController.clear();

    setState(() {
      displayedOrders = allOrders;
      hasSearched = false;
    });
  }

  // Convert the saved order items into a safe list.
  List<Map<String, dynamic>> getOrderItems(
    Map<String, dynamic> data,
  ) {
    final dynamic savedItems = data['items'];

    if (savedItems is! List) return [];

    return savedItems.map((item) {
      if (item is Map) {
        return Map<String, dynamic>.from(item);
      }
      return <String, dynamic>{};
    }).toList();
  }

  // Get the item total, or calculate it if it was not saved.
  double getItemTotal(Map<String, dynamic> item) {
    final dynamic savedTotal = item['total'];

    if (savedTotal != null) {
      return double.tryParse(savedTotal.toString()) ?? 0;
    }

    final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;

    final int quantity = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;

    return price * quantity;
  }

  // Read the date saved with the order.
  String getOrderDate(Map<String, dynamic> data) {
    return data['date']?.toString() ?? '';
  }

  // Open the saved order as a duplicate receipt.
  void openDuplicateReceipt(Map<String, dynamic> data) {
    final int orderNumber = int.tryParse(
          data['orderNo']?.toString() ?? '',
        ) ??
        int.tryParse(data['id']?.toString() ?? '') ??
        0;

    final String date = getOrderDate(data);
    final String customerName = data['customerName']?.toString() ?? '';
    final List<Map<String, dynamic>> items = getOrderItems(data);

    final double grandTotal =
        double.tryParse(data['grandTotal']?.toString() ?? '0') ?? 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptScreen(
          orderNumber: orderNumber,
          date: date,
          customerName: customerName,
          orderItems: items,
          grandTotal: grandTotal,
          isDuplicate: true,
        ),
      ),
    );
  }

  // Build a card displaying one saved order.
  Widget buildOrderCard(QueryDocumentSnapshot order) {
    final data = order.data() as Map<String, dynamic>;

    final List<Map<String, dynamic>> items = getOrderItems(data);

    final double grandTotal =
        double.tryParse(data['grandTotal']?.toString() ?? '0') ?? 0;

    final String orderNumber = data['orderNo']?.toString() ?? order.id;
    final String date = data['date']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF0E1D7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order number and date.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5D5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: pizzaRed,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order No. $orderNumber',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE7D8CD)),

            // Display each item, its quantity, size and total.
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No items found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...items.map((item) {
                final String itemName = item['itemName']?.toString() ?? '';

                final String size = item['size']?.toString() ?? '';

                final int quantity =
                    int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;

                final String price = item['price']?.toString() ?? '0';

                final double total = getItemTotal(item);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              itemName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: darkText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Qty: $quantity',
                            style: const TextStyle(
                              fontSize: 14,
                              color: darkText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              size.isNotEmpty ? 'Size: $size' : '',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Rs. $price × $quantity = Rs. ${total.toStringAsFixed(0)}',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 13,
                                color: darkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

            const Divider(color: Color(0xFFE7D8CD)),
            const SizedBox(height: 5),

            // Show the saved order's grand total.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                Flexible(
                  child: Text(
                    'Rs. ${grandTotal.toStringAsFixed(0)}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: pizzaRed,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Print the duplicate receipt using the existing receipt screen.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pizzaRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  openDuplicateReceipt({
                    ...data,
                    'id': order.id,
                  });
                },
                icon: const Icon(Icons.print),
                label: const Text(
                  'Print Receipt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find Order',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: pizzaRed,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      backgroundColor: creamBackground,
      body: Column(
        children: [
          // Search field and button.
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: orderController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Enter Order Number',
                          hintText: 'e.g. 1',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: pizzaRed,
                          ),
                          filled: true,
                          fillColor: creamBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE7D8CD),
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
                        onSubmitted: (_) => searchOrder(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pizzaRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: searchOrder,
                        child: const Text('Search'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Show the reset button after a search.
          if (hasSearched)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pizzaRed,
                    side: const BorderSide(color: pizzaRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: showAllOrders,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Show All Orders'),
                ),
              ),
            ),

          // Display loading, empty results, or the saved orders.
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: pizzaRed),
                  )
                : displayedOrders.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 55,
                                color: pizzaOrange,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                hasSearched
                                    ? 'Order not found'
                                    : 'No orders found',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: darkText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                        itemCount: displayedOrders.length,
                        itemBuilder: (context, index) {
                          return buildOrderCard(displayedOrders[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
