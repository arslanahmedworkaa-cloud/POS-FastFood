import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'receipt_screen.dart';

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

  // Load all saved orders
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

      orders.sort(
        (a, b) {
          final int aNumber = int.tryParse(a.id) ?? 0;
          final int bNumber = int.tryParse(b.id) ?? 0;

          return aNumber.compareTo(bNumber);
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        allOrders = orders;
        displayedOrders = orders;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading orders: $e',
          ),
        ),
      );
    }
  }

  // Search order by number
  void searchOrder() {
    final String searchText = orderController.text.trim();

    if (searchText.isEmpty) {
      setState(() {
        displayedOrders = allOrders;
        hasSearched = false;
      });

      return;
    }

    final List<QueryDocumentSnapshot> results = allOrders.where(
      (order) {
        final String orderNumber = order.id;

        return orderNumber == searchText;
      },
    ).toList();

    setState(() {
      displayedOrders = results;
      hasSearched = true;
    });
  }

  // Show all orders again
  void showAllOrders() {
    orderController.clear();

    setState(() {
      displayedOrders = allOrders;
      hasSearched = false;
    });
  }

  // Convert saved order items
  List<Map<String, dynamic>> getOrderItems(
    Map<String, dynamic> data,
  ) {
    final dynamic savedItems = data['items'];

    if (savedItems is! List) {
      return [];
    }

    return savedItems.map(
      (item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }

        return <String, dynamic>{};
      },
    ).toList();
  }

  // Get item total
  double getItemTotal(
    Map<String, dynamic> item,
  ) {
    final dynamic savedTotal = item['total'];

    if (savedTotal != null) {
      return double.tryParse(
            savedTotal.toString(),
          ) ??
          0;
    }

    final double price = double.tryParse(
          item['price']?.toString() ?? '0',
        ) ??
        0;

    final int quantity = int.tryParse(
          item['quantity']?.toString() ?? '0',
        ) ??
        0;

    return price * quantity;
  }

  // Format date
  String getOrderDate(
    Map<String, dynamic> data,
  ) {
    return data['date']?.toString() ?? '';
  }

  // Open duplicate receipt
  void openDuplicateReceipt(
    Map<String, dynamic> data,
  ) {
    final int orderNumber = int.tryParse(
          data['orderNo']?.toString() ?? '',
        ) ??
        int.tryParse(
          data['id']?.toString() ?? '',
        ) ??
        0;

    final String date = getOrderDate(data);

    final String customerName = data['customerName']?.toString() ?? '';

    final List<Map<String, dynamic>> items = getOrderItems(data);

    final double grandTotal = double.tryParse(
          data['grandTotal']?.toString() ?? '0',
        ) ??
        0;

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

  // Build one order card
  Widget buildOrderCard(
    QueryDocumentSnapshot order,
  ) {
    final data = order.data() as Map<String, dynamic>;

    final List<Map<String, dynamic>> items = getOrderItems(data);

    final double grandTotal = double.tryParse(
          data['grandTotal']?.toString() ?? '0',
        ) ??
        0;

    final String orderNumber = data['orderNo']?.toString() ?? order.id;

    final String date = data['date']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 15,
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order heading
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order No. $orderNumber',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),

            const Divider(),

            const SizedBox(
              height: 5,
            ),

            // Items
            if (items.isEmpty)
              const Text(
                'No items found',
              )
            else
              ...items.map(
                (item) {
                  final String itemName = item['itemName']?.toString() ?? '';

                  final String size = item['size']?.toString() ?? '';

                  final int quantity = int.tryParse(
                        item['quantity']?.toString() ?? '0',
                      ) ??
                      0;

                  final String price = item['price']?.toString() ?? '0';

                  final double total = getItemTotal(item);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 7,
                    ),
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
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              'Qty: $quantity',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (size.isNotEmpty)
                              Text(
                                'Size: $size',
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              )
                            else
                              const SizedBox(),
                            Text(
                              'Rs. $price × $quantity = Rs. ${total.toStringAsFixed(0)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

            const Divider(),

            const SizedBox(
              height: 5,
            ),

            // Grand total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Rs. ${grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            // Print duplicate receipt
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  openDuplicateReceipt(
                    {
                      ...data,
                      'id': order.id,
                    },
                  );
                },
                icon: const Icon(
                  Icons.print,
                ),
                label: const Text(
                  'Print Receipt',
                  style: TextStyle(
                    fontSize: 16,
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
        title: const Text('Find Order'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Column(
        children: [
          // Search area
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter Order Number',
                      hintText: 'e.g. 1',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.search,
                      ),
                    ),
                    onSubmitted: (_) {
                      searchOrder();
                    },
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: searchOrder,
                    child: const Text(
                      'Search',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Show all button after search
          if (hasSearched)
            Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: 5,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: showAllOrders,
                  child: const Text(
                    'Show All Orders',
                  ),
                ),
              ),
            ),

          // Orders
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : displayedOrders.isEmpty
                    ? Center(
                        child: Text(
                          hasSearched ? 'Order not found' : 'No orders found',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          20,
                        ),
                        itemCount: displayedOrders.length,
                        itemBuilder: (
                          context,
                          index,
                        ) {
                          return buildOrderCard(
                            displayedOrders[index],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
