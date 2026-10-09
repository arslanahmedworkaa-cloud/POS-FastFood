import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'receipt_screen.dart';

class CancelOrderScreen extends StatefulWidget {
  const CancelOrderScreen({super.key});

  @override
  State<CancelOrderScreen> createState() => _CancelOrderScreenState();
}

class _CancelOrderScreenState extends State<CancelOrderScreen> {
  final TextEditingController orderController = TextEditingController();

  final ScrollController ordersListController = ScrollController();

  String searchedOrderNumber = '';

  @override
  void dispose() {
    orderController.dispose();
    ordersListController.dispose();
    super.dispose();
  }

  void searchOrder() {
    final String value = orderController.text.trim();

    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an order number'),
        ),
      );

      return;
    }

    setState(() {
      searchedOrderNumber = value;
    });
  }

  void showAllOrders() {
    orderController.clear();

    setState(() {
      searchedOrderNumber = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cancel Order'),
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
        title: const Text('Cancel Order'),
        backgroundColor: Colors.orangeAccent,
      ),
      backgroundColor: const Color(0xffc6d1d7),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Order Number',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      searchOrder();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: searchOrder,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          if (searchedOrderNumber.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: 12,
                  bottom: 5,
                ),
                child: TextButton(
                  onPressed: showAllOrders,
                  child: const Text('Show All Orders'),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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

                  final String orderNumber =
                      data['orderNo']?.toString() ?? order.id;

                  if (searchedOrderNumber.isEmpty ||
                      orderNumber == searchedOrderNumber) {
                    filteredOrders.add(order);
                  }
                }

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Text(
                      searchedOrderNumber.isEmpty
                          ? 'No orders found'
                          : 'Order not found',
                      style: const TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  key: const PageStorageKey(
                    'cancel_orders_list',
                  ),
                  controller: ordersListController,
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    5,
                    12,
                    20,
                  ),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final QueryDocumentSnapshot order = filteredOrders[index];

                    final Map<String, dynamic> data =
                        order.data() as Map<String, dynamic>;

                    final String orderNumber =
                        data['orderNo']?.toString() ?? order.id;

                    return _OrderCard(
                      key: ValueKey(orderNumber),
                      order: order,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final QueryDocumentSnapshot order;

  const _OrderCard({
    super.key,
    required this.order,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard>
    with AutomaticKeepAliveClientMixin {
  late String orderNumber;
  late String date;
  late String customerName;

  List<Map<String, dynamic>> items = [];

  List<bool> selectedItems = [];

  late ScrollController verticalController;
  late ScrollController horizontalController;

  bool isDeleting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    verticalController = ScrollController();
    horizontalController = ScrollController();

    loadOrderData();
  }

  @override
  void didUpdateWidget(covariant _OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.order.id != widget.order.id) {
      loadOrderData();
    } else {
      final Map<String, dynamic> data =
          widget.order.data() as Map<String, dynamic>;

      final List<Map<String, dynamic>> newItems = getItems(data);

      if (newItems.length != items.length) {
        items = newItems;
        selectedItems = List<bool>.filled(
          items.length,
          false,
        );
      } else {
        items = newItems;
      }

      orderNumber = data['orderNo']?.toString() ?? widget.order.id;

      date = getDateText(data['date']);

      customerName = data['customerName']?.toString() ?? '';
    }
  }

  void loadOrderData() {
    final Map<String, dynamic> data =
        widget.order.data() as Map<String, dynamic>;

    orderNumber = data['orderNo']?.toString() ?? widget.order.id;

    date = getDateText(data['date']);

    customerName = data['customerName']?.toString() ?? '';

    items = getItems(data);

    selectedItems = List<bool>.filled(
      items.length,
      false,
    );
  }

  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  double getNumber(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().replaceAll(',', '') ?? '',
        ) ??
        0;
  }

  String formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  double getItemTotal(Map<String, dynamic> item) {
    if (item['total'] != null) {
      return getNumber(item['total']);
    }

    final double price = getNumber(item['price']);
    final double quantity = getNumber(item['quantity']);

    return price * quantity;
  }

  String getDateText(dynamic date) {
    if (date == null) {
      return '';
    }

    if (date is Timestamp) {
      final DateTime value = date.toDate();

      return '${value.day.toString().padLeft(2, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.year}';
    }

    return date.toString();
  }

  List<Map<String, dynamic>> getItems(
    Map<String, dynamic> data,
  ) {
    final List<Map<String, dynamic>> result = [];

    final dynamic storedItems = data['items'];

    if (storedItems is List) {
      for (final item in storedItems) {
        if (item is Map) {
          result.add(
            Map<String, dynamic>.from(item),
          );
        }
      }
    }

    return result;
  }

  double getGrandTotal(
    Map<String, dynamic> data,
  ) {
    double total = 0;

    for (final item in items) {
      total += getItemTotal(item);
    }

    if (data['grandTotal'] != null) {
      final double storedTotal = getNumber(data['grandTotal']);

      if (storedTotal > 0) {
        total = storedTotal;
      }
    }

    return total;
  }

  bool get allSelected {
    if (selectedItems.isEmpty) {
      return false;
    }

    return selectedItems.every(
      (value) => value,
    );
  }

  void selectItem(
    int index,
    bool value,
  ) {
    if (isDeleting) {
      return;
    }

    setState(() {
      selectedItems[index] = value;
    });
  }

  void selectAll() {
    if (isDeleting) {
      return;
    }

    final bool value = !allSelected;

    setState(() {
      selectedItems = List<bool>.filled(
        items.length,
        value,
      );
    });
  }

  Future<void> confirmDelete(
    Map<String, dynamic> orderData,
  ) async {
    bool hasSelectedItem = selectedItems.any(
      (value) => value,
    );

    if (!hasSelectedItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one item',
          ),
        ),
      );

      return;
    }

    final bool deleteAll = selectedItems.every(
      (value) => value,
    );

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: Text(
            deleteAll
                ? 'Are you sure you want to cancel this complete order?'
                : 'Are you sure you want to cancel the selected item(s)?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      isDeleting = true;
    });

    try {
      final DocumentReference orderReference = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .doc(orderNumber);

      if (deleteAll) {
        await orderReference.delete();

        if (!mounted) {
          return;
        }

        setState(() {
          isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Order deleted successfully',
            ),
          ),
        );

        return;
      }

      final List<Map<String, dynamic>> remainingItems = [];

      for (int i = 0; i < items.length; i++) {
        if (!selectedItems[i]) {
          remainingItems.add(items[i]);
        }
      }

      double newGrandTotal = 0;

      for (final item in remainingItems) {
        newGrandTotal += getItemTotal(item);
      }

      await orderReference.update({
        'items': remainingItems,
        'grandTotal': formatPrice(newGrandTotal),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        isDeleting = false;
        selectedItems = List<bool>.filled(
          remainingItems.length,
          false,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selected items cancelled successfully',
          ),
        ),
      );

      final int savedOrderNumber = int.tryParse(
            orderData['orderNo']?.toString() ?? '',
          ) ??
          int.tryParse(orderNumber) ??
          0;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiptScreen(
            orderNumber: savedOrderNumber,
            date: date,
            customerName: customerName,
            orderItems: remainingItems,
            grandTotal: newGrandTotal,
            isDuplicate: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error cancelling order: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final Map<String, dynamic> data =
        widget.order.data() as Map<String, dynamic>;

    final double grandTotal = getGrandTotal(data);

    // Keeps the table compact for small orders,
    // but allows scrolling for larger orders.
    final double tableHeight =
        items.length <= 4 ? 70 + (items.length * 58) : 330;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 15,
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order No: $orderNumber',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Date: $date',
              style: const TextStyle(
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No items in this order',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              )
            else
              SizedBox(
                height: tableHeight,
                child: Scrollbar(
                  controller: verticalController,
                  thumbVisibility: items.length > 4,
                  child: SingleChildScrollView(
                    controller: verticalController,
                    child: Scrollbar(
                      controller: horizontalController,
                      thumbVisibility: true,
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
                          child: Column(
                            children: [
                              Container(
                                width: 700,
                                height: 42,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(
                                  right: 10,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Select All',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    GestureDetector(
                                      onTap: selectAll,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            width: 2,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        child: allSelected
                                            ? Center(
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration:
                                                      const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.orangeAccent,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataTable(
                                border: TableBorder.all(
                                  color: Colors.grey,
                                ),
                                headingRowHeight: 45,
                                dataRowMinHeight: 52,
                                dataRowMaxHeight: 58,
                                columnSpacing: 35,
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'S.No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Item',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Quantity',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Price',
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
                                  DataColumn(
                                    label: Text(
                                      'Select',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: List.generate(
                                  items.length,
                                  (index) {
                                    final Map<String, dynamic> item =
                                        items[index];

                                    final String itemName =
                                        item['itemName']?.toString() ?? '';

                                    final double quantity = getNumber(
                                      item['quantity'],
                                    );

                                    final double price = getNumber(
                                      item['price'],
                                    );

                                    final double total = getItemTotal(
                                      item,
                                    );

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 190,
                                            child: Text(
                                              itemName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            formatPrice(
                                              quantity,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            'Rs. ${formatPrice(price)}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            'Rs. ${formatPrice(total)}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          GestureDetector(
                                            onTap: () {
                                              selectItem(
                                                index,
                                                !selectedItems[index],
                                              );
                                            },
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  width: 2,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              child: selectedItems[index]
                                                  ? Center(
                                                      child: Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration:
                                                            const BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: Colors
                                                              .orangeAccent,
                                                        ),
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
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
                    'Rs. ${formatPrice(grandTotal)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: isDeleting
                    ? null
                    : () {
                        confirmDelete(data);
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm',
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
}
