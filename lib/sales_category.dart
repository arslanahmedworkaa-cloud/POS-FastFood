import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalesCategoryScreen extends StatefulWidget {
  const SalesCategoryScreen({super.key});

  @override
  State<SalesCategoryScreen> createState() => _SalesCategoryScreenState();
}

class _SalesCategoryScreenState extends State<SalesCategoryScreen> {
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
      });
    }
  }

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
      return DateTime.tryParse(savedDate);
    }

    return null;
  }

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

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

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sales - Category Wise'),
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
        title: const Text('Sales - Category Wise'),
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

          final List<QueryDocumentSnapshot> filteredOrders = [];

          for (final order in allOrders) {
            final Map<String, dynamic> orderData =
                order.data() as Map<String, dynamic>;

            final DateTime? orderDate = getOrderDate(orderData);

            if (orderDate != null && isOrderInSelectedRange(orderDate)) {
              filteredOrders.add(order);
            }
          }

          final Map<String, int> categoryQuantities = {};
          final Map<String, double> categoryTotals = {};

          for (final order in filteredOrders) {
            final Map<String, dynamic> orderData =
                order.data() as Map<String, dynamic>;

            final List<dynamic> items =
                orderData['items'] as List<dynamic>? ?? [];

            for (final item in items) {
              final Map<String, dynamic> itemData =
                  Map<String, dynamic>.from(item as Map);

              final String categoryName =
                  itemData['categoryName']?.toString() ?? 'Unknown Category';

              final int quantity = (itemData['quantity'] as num?)?.toInt() ?? 0;

              final double itemTotal =
                  (itemData['total'] as num?)?.toDouble() ?? 0;

              categoryQuantities[categoryName] =
                  (categoryQuantities[categoryName] ?? 0) + quantity;

              categoryTotals[categoryName] =
                  (categoryTotals[categoryName] ?? 0) + itemTotal;
            }
          }

          final List<String> categories = categoryQuantities.keys.toList();

          categories.sort();

          double grandTotal = 0;

          for (final category in categories) {
            grandTotal += categoryTotals[category] ?? 0;
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
                            suffixIcon: Icon(Icons.calendar_month),
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
                            suffixIcon: Icon(Icons.calendar_month),
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

                if (categories.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No sales found',
                        style: TextStyle(fontSize: 18),
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
                                      minWidth: 600,
                                    ),
                                    child: DataTable(
                                      headingRowHeight: 50,
                                      dataRowMinHeight: 55,
                                      dataRowMaxHeight: 65,
                                      columnSpacing: 40,
                                      columns: const [
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
                                      rows: categories.map((category) {
                                        final int quantity =
                                            categoryQuantities[category] ?? 0;

                                        final double total =
                                            categoryTotals[category] ?? 0;

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                category,
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
