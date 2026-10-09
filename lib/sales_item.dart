import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalesItemScreen extends StatefulWidget {
  const SalesItemScreen({super.key});

  @override
  State<SalesItemScreen> createState() => _SalesItemScreenState();
}

class _SalesItemScreenState extends State<SalesItemScreen> {
  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

  DateTime? fromDate;
  DateTime? toDate;

  bool searchClicked = false;

  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  Future<void> selectFromDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      setState(() {
        fromDate = selectedDate;
        searchClicked = false;
      });
    }
  }

  Future<void> selectToDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      setState(() {
        toDate = selectedDate;
        searchClicked = false;
      });
    }
  }

  // Getting the date of an order from Firebase
  DateTime? getOrderDate(Map<String, dynamic> data) {
    final dynamic createdAt = data['createdAt'];

    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }

    final dynamic savedDate = data['date'];

    if (savedDate is Timestamp) {
      return savedDate.toDate();
    }

    if (savedDate is String) {
      // Receipt date format: dd-MM-yyyy
      final List<String> parts = savedDate.split('-');

      if (parts.length == 3) {
        final int? day = int.tryParse(parts[0]);
        final int? month = int.tryParse(parts[1]);
        final int? year = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }

      // Also support normal ISO date if it exists
      return DateTime.tryParse(savedDate);
    }

    return null;
  }

  // Formatting date for the screen
  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // Checking whether an order belongs to selected dates
  bool isOrderInSelectedRange(DateTime orderDate) {
    if (!searchClicked) {
      return true;
    }

    if (fromDate == null || toDate == null) {
      return false;
    }

    final DateTime startDate = DateTime(
      fromDate!.year,
      fromDate!.month,
      fromDate!.day,
    );

    final DateTime endDate = DateTime(
      toDate!.year,
      toDate!.month,
      toDate!.day,
      23,
      59,
      59,
      999,
    );

    return !orderDate.isBefore(startDate) && !orderDate.isAfter(endDate);
  }

  // Safely converting Firebase values to integer
  int getQuantity(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  // Safely converting Firebase values to double
  double getDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sales - Item Wise'),
          backgroundColor: Colors.orangeAccent,
        ),
        body: const Center(
          child: Text('User not logged in'),
        ),
      );
    }

    final CollectionReference orders = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('orders');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales - Item Wise'),
        backgroundColor: Colors.orangeAccent,
      ),
      backgroundColor: const Color(0xffc6d1d7),
      body: StreamBuilder<QuerySnapshot>(
        stream: orders.snapshots(),
        builder: (context, snapshot) {
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

          final List<QueryDocumentSnapshot> allOrders =
              snapshot.data?.docs ?? [];

          // Filtering orders according to selected dates
          final List<QueryDocumentSnapshot> filteredOrders = [];

          for (final order in allOrders) {
            final Map<String, dynamic> orderData =
                order.data() as Map<String, dynamic>;

            final DateTime? orderDate = getOrderDate(orderData);

            if (orderDate != null && isOrderInSelectedRange(orderDate)) {
              filteredOrders.add(order);
            }
          }

          /*
            Key:
            Item Name + Size + Price

            This makes separate rows such as:

            Pizza | Small  | 800  | 4 | 3200
            Pizza | Medium | 1000 | 3 | 3000
            Burger| Regular| 500  | 2 | 1000

            So different sizes/prices of the same item
            are shown separately.
          */
          final Map<String, Map<String, dynamic>> itemSales = {};

          for (final order in filteredOrders) {
            final Map<String, dynamic> orderData =
                order.data() as Map<String, dynamic>;

            final List<dynamic> items =
                orderData['items'] as List<dynamic>? ?? [];

            for (final item in items) {
              if (item is! Map) {
                continue;
              }

              final Map<String, dynamic> itemData =
                  Map<String, dynamic>.from(item);

              final String itemName =
                  itemData['itemName']?.toString() ?? 'Unknown Item';

              final String size = itemData['size']?.toString() ?? '';

              final double price = getDouble(itemData['price']);

              final int quantity = getQuantity(itemData['quantity']);

              /*
                Normally total is already saved in the order.

                We use the saved total because the order was
                completed using that exact value.

                If total is missing, price × quantity is used
                as a safe fallback.
              */
              double itemTotal;

              if (itemData['total'] != null) {
                itemTotal = getDouble(itemData['total']);
              } else {
                itemTotal = price * quantity;
              }

              final String key = '${itemName.toLowerCase()}|'
                  '${size.toLowerCase()}|'
                  '${price.toStringAsFixed(2)}';

              if (!itemSales.containsKey(key)) {
                itemSales[key] = {
                  'itemName': itemName,
                  'size': size,
                  'price': price,
                  'quantity': 0,
                  'total': 0.0,
                };
              }

              itemSales[key]!['quantity'] =
                  (itemSales[key]!['quantity'] as int) + quantity;

              itemSales[key]!['total'] =
                  (itemSales[key]!['total'] as double) + itemTotal;
            }
          }

          final List<Map<String, dynamic>> items = itemSales.values.toList();

          // Sorting by item name and then by size
          items.sort((a, b) {
            final String itemA = a['itemName']?.toString().toLowerCase() ?? '';

            final String itemB = b['itemName']?.toString().toLowerCase() ?? '';

            final int itemComparison = itemA.compareTo(itemB);

            if (itemComparison != 0) {
              return itemComparison;
            }

            final String sizeA = a['size']?.toString().toLowerCase() ?? '';

            final String sizeB = b['size']?.toString().toLowerCase() ?? '';

            return sizeA.compareTo(sizeB);
          });

          // Calculating the grand total from all item totals
          double grandTotal = 0;

          for (final item in items) {
            grandTotal += getDouble(item['total']);
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // From and To date selection
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: selectFromDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'From',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(
                              Icons.calendar_month,
                            ),
                          ),
                          child: Text(
                            fromDate == null
                                ? 'Select date'
                                : formatDate(fromDate!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: selectToDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'To',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(
                              Icons.calendar_month,
                            ),
                          ),
                          child: Text(
                            toDate == null
                                ? 'Select date'
                                : formatDate(toDate!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (fromDate == null || toDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select both From and To dates',
                              ),
                            ),
                          );
                          return;
                        }

                        if (fromDate!.isAfter(toDate!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'From date cannot be after To date',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() {
                          searchClicked = true;
                        });
                      },
                      child: const Text('Search'),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                if (items.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No sales found',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                  )
                else
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
                                      minWidth: 650,
                                    ),
                                    child: DataTable(
                                      headingRowHeight: 50,
                                      dataRowMinHeight: 55,
                                      dataRowMaxHeight: 65,
                                      columnSpacing: 40,
                                      columns: const [
                                        DataColumn(
                                          label: Text(
                                            'Item',
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
                                            'Quantity',
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
                                      ],
                                      rows: items.map((item) {
                                        final String itemName =
                                            item['itemName']?.toString() ?? '';

                                        final String size =
                                            item['size']?.toString() ?? '';

                                        final double price =
                                            getDouble(item['price']);

                                        final int quantity =
                                            getQuantity(item['quantity']);

                                        final double total =
                                            getDouble(item['total']);

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                itemName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                size.isEmpty ? 'N/A' : size,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                'Rs. ${price.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                quantity.toString(),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                'Rs. ${total.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 16,
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

                const SizedBox(height: 12),

                // Grand Total
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
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
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
