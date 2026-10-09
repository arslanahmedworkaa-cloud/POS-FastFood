import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalesOrderScreen extends StatefulWidget {
  const SalesOrderScreen({super.key});

  @override
  State<SalesOrderScreen> createState() => _SalesOrderScreenState();
}

class _SalesOrderScreenState extends State<SalesOrderScreen> {
  DateTime? fromDate;
  DateTime? toDate;

  bool searchClicked = false;

  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

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
          title: const Text('Daily Sales'),
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
        title: const Text('Daily Sales'),
        backgroundColor: Colors.orangeAccent,
      ),
      backgroundColor: const Color(0xffc6d1d7),
      body: StreamBuilder<QuerySnapshot>(
        stream: orders.orderBy('orderNo').snapshots(),
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
            final Map<String, dynamic> data =
                order.data() as Map<String, dynamic>;

            final DateTime? orderDate = getOrderDate(data);

            if (orderDate != null && isOrderInSelectedRange(orderDate)) {
              filteredOrders.add(order);
            }
          }

          double grandTotal = 0;

          for (final order in filteredOrders) {
            final Map<String, dynamic> data =
                order.data() as Map<String, dynamic>;

            grandTotal += double.tryParse(
                  data['grandTotal']?.toString() ?? '0',
                ) ??
                0;
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

                if (filteredOrders.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No orders found',
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
                                      minWidth: 650,
                                    ),
                                    child: DataTable(
                                      border: TableBorder.all(
                                        color: Colors.grey,
                                      ),
                                      headingRowHeight: 50,
                                      dataRowMinHeight: 55,
                                      dataRowMaxHeight: 65,
                                      columnSpacing: 40,
                                      columns: const [
                                        DataColumn(
                                          label: Text(
                                            'Date',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Order Number',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Total',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: filteredOrders.map((order) {
                                        final Map<String, dynamic> data = order
                                            .data() as Map<String, dynamic>;

                                        final DateTime? orderDate =
                                            getOrderDate(data);

                                        final int orderNumber = int.tryParse(
                                              data['orderNo']?.toString() ??
                                                  '0',
                                            ) ??
                                            0;

                                        final double total = double.tryParse(
                                              data['grandTotal']?.toString() ??
                                                  '0',
                                            ) ??
                                            0;

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                orderDate == null
                                                    ? ''
                                                    : formatDate(orderDate),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                'Order No.$orderNumber',
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
