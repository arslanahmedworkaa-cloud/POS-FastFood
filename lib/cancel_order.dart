import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'receipt_screen.dart';

// These colors give the Cancel Order screen the same modern food-app theme.
const Color cancelPizzaRed = Color(0xFFD93636);
const Color cancelPizzaOrange = Color(0xFFFF8A3D);
const Color cancelCreamBackground = Color(0xFFFFF8F1);
const Color cancelDarkText = Color(0xFF292524);

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

  // Search for an order using its order number.
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

  // Clear the search and show all orders again.
  void showAllOrders() {
    orderController.clear();

    setState(() {
      searchedOrderNumber = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    // Show this message if no user is signed in.
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cancel Order'),
          backgroundColor: cancelPizzaRed,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        backgroundColor: cancelCreamBackground,
        body: const Center(
          child: Text(
            'User not logged in',
            style: TextStyle(
              fontSize: 16,
              color: cancelDarkText,
            ),
          ),
        ),
      );
    }

    // Keep the existing Firestore orders collection.
    final CollectionReference orders = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('orders');

    return Scaffold(
      backgroundColor: cancelCreamBackground,
      appBar: AppBar(
        title: const Text(
          'Cancel Order',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),
        backgroundColor: cancelPizzaRed,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search area with a rounded input and matching button.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Order Number',
                      labelStyle: const TextStyle(
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.receipt_long_rounded,
                        color: cancelPizzaRed,
                      ),
                      filled: true,
                      fillColor: cancelCreamBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.orange.shade100,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: cancelPizzaRed,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) {
                      searchOrder();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: searchOrder,
                    icon: const Icon(Icons.search_rounded, size: 20),
                    label: const Text('Search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cancelPizzaRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Show the reset option only when a search is active.
          if (searchedOrderNumber.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: 16,
                  top: 5,
                  bottom: 2,
                ),
                child: TextButton.icon(
                  onPressed: showAllOrders,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                  ),
                  label: const Text('Show All Orders'),
                  style: TextButton.styleFrom(
                    foregroundColor: cancelPizzaRed,
                  ),
                ),
              ),
            ),

          // StreamBuilder keeps the displayed orders updated from Firestore.
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: orders.orderBy('orderNo').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: cancelPizzaRed,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(
                          color: cancelDarkText,
                        ),
                      ),
                    ),
                  );
                }

                final List<QueryDocumentSnapshot> allOrders =
                    snapshot.data?.docs ?? [];

                final List<QueryDocumentSnapshot> filteredOrders = [];

                // Keep the original order-number filtering behavior.
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
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.orange.shade100,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            searchedOrderNumber.isEmpty
                                ? Icons.receipt_long_outlined
                                : Icons.search_off_rounded,
                            size: 52,
                            color: cancelPizzaOrange,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            searchedOrderNumber.isEmpty
                                ? 'No orders found'
                                : 'Order not found',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cancelDarkText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            searchedOrderNumber.isEmpty
                                ? 'Your orders will appear here.'
                                : 'Please check the order number and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  key: const PageStorageKey('cancel_orders_list'),
                  controller: ordersListController,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
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
        selectedItems = List<bool>.filled(items.length, false);
      } else {
        items = newItems;
      }

      orderNumber = data['orderNo']?.toString() ?? widget.order.id;
      date = getDateText(data['date']);
      customerName = data['customerName']?.toString() ?? '';
    }
  }

  // Read the existing order data without changing its structure.
  void loadOrderData() {
    final Map<String, dynamic> data =
        widget.order.data() as Map<String, dynamic>;

    orderNumber = data['orderNo']?.toString() ?? widget.order.id;
    date = getDateText(data['date']);
    customerName = data['customerName']?.toString() ?? '';

    items = getItems(data);
    selectedItems = List<bool>.filled(items.length, false);
  }

  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  // Convert saved numeric values safely.
  double getNumber(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().replaceAll(',', '') ?? '',
        ) ??
        0;
  }

  // Display whole numbers without unnecessary decimal places.
  String formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // Use the saved item total, or calculate it when no total is saved.
  double getItemTotal(Map<String, dynamic> item) {
    if (item['total'] != null) {
      return getNumber(item['total']);
    }

    final double price = getNumber(item['price']);
    final double quantity = getNumber(item['quantity']);

    return price * quantity;
  }

  // Convert Firestore timestamps to a readable date.
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

  // Safely read the list of items saved with the order.
  List<Map<String, dynamic>> getItems(
    Map<String, dynamic> data,
  ) {
    final List<Map<String, dynamic>> result = [];
    final dynamic storedItems = data['items'];

    if (storedItems is List) {
      for (final item in storedItems) {
        if (item is Map) {
          result.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return result;
  }

  // Calculate the order total while preserving the saved grand total behavior.
  double getGrandTotal(Map<String, dynamic> data) {
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

  // Check whether every item is selected.
  bool get allSelected {
    if (selectedItems.isEmpty) {
      return false;
    }

    return selectedItems.every((value) => value);
  }

  // Select or deselect an individual item.
  void selectItem(int index, bool value) {
    if (isDeleting) {
      return;
    }

    setState(() {
      selectedItems[index] = value;
    });
  }

  // Select all items, or clear the current selection.
  void selectAll() {
    if (isDeleting) {
      return;
    }

    final bool value = !allSelected;

    setState(() {
      selectedItems = List<bool>.filled(items.length, value);
    });
  }

  // Ask for confirmation before deleting an order or cancelling items.
  Future<void> confirmDelete(
    Map<String, dynamic> orderData,
  ) async {
    final bool hasSelectedItem = selectedItems.any((value) => value);

    if (!hasSelectedItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item'),
        ),
      );
      return;
    }

    final bool deleteAll = selectedItems.every((value) => value);

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: cancelPizzaRed,
                size: 27,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text('Cancel Order'),
              ),
            ],
          ),
          content: Text(
            deleteAll
                ? 'Are you sure you want to cancel this complete order?'
                : 'Are you sure you want to cancel the selected item(s)?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              style: TextButton.styleFrom(
                foregroundColor: cancelDarkText,
              ),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cancelPizzaRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Yes, Cancel'),
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
      // Keep the existing order reference used by your app.
      final DocumentReference orderReference = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .doc(orderNumber);

      // Delete the complete order when every item is selected.
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
            content: Text('Order deleted successfully'),
          ),
        );

        return;
      }

      // Keep only the items that were not selected.
      final List<Map<String, dynamic>> remainingItems = [];

      for (int i = 0; i < items.length; i++) {
        if (!selectedItems[i]) {
          remainingItems.add(items[i]);
        }
      }

      // Recalculate the total after removing the selected items.
      double newGrandTotal = 0;

      for (final item in remainingItems) {
        newGrandTotal += getItemTotal(item);
      }

      // Update the existing order with the remaining items and total.
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
          content: Text('Selected items cancelled successfully'),
        ),
      );

      // Open the receipt showing the updated order.
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
          content: Text('Error cancelling order: $e'),
        ),
      );
    }
  }

  // Build a round selection indicator using the app's orange accent.
  Widget buildSelectionCircle({
    required bool selected,
    required VoidCallback onTap,
    double size = 24,
  }) {
    return InkWell(
      onTap: isDeleting ? null : onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? cancelPizzaOrange : Colors.transparent,
          border: Border.all(
            width: 2,
            color: selected ? cancelPizzaOrange : Colors.grey.shade500,
          ),
        ),
        child: selected
            ? const Icon(
                Icons.check_rounded,
                size: 16,
                color: Colors.white,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final Map<String, dynamic> data =
        widget.order.data() as Map<String, dynamic>;

    final double grandTotal = getGrandTotal(data);

    // Keep the table compact for small orders and scrollable for larger ones.
    final double tableHeight =
        items.length <= 4 ? 70 + (items.length * 58) : 330;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 3,
      shadowColor: cancelPizzaRed.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.orange.shade100,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order information header.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cancelPizzaRed.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: cancelPizzaRed,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order No: $orderNumber',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cancelDarkText,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Date: $date',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Show a friendly message if an order has no items.
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cancelCreamBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No items in this order',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              )
            else
              // Keep both scroll directions so wide tables remain usable.
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
                        child: SizedBox(
                          width: 700,
                          child: Column(
                            children: [
                              // Select All control.
                              Container(
                                width: 700,
                                height: 44,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: cancelCreamBackground,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Select All',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: cancelDarkText,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    buildSelectionCircle(
                                      selected: allSelected,
                                      size: 23,
                                      onTap: selectAll,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Table styling changes only the presentation.
                              Theme(
                                data: Theme.of(context).copyWith(
                                  dataTableTheme: DataTableThemeData(
                                    headingRowColor: WidgetStateProperty.all(
                                      cancelPizzaRed,
                                    ),
                                    headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    dataTextStyle: const TextStyle(
                                      fontSize: 14,
                                      color: cancelDarkText,
                                    ),
                                    dividerThickness: 0.8,
                                  ),
                                ),
                                child: DataTable(
                                  border: TableBorder.all(
                                    color: Colors.orange.shade100,
                                  ),
                                  headingRowHeight: 45,
                                  dataRowMinHeight: 52,
                                  dataRowMaxHeight: 58,
                                  columnSpacing: 35,
                                  columns: const [
                                    DataColumn(label: Text('S.No')),
                                    DataColumn(label: Text('Item')),
                                    DataColumn(label: Text('Quantity')),
                                    DataColumn(label: Text('Price')),
                                    DataColumn(label: Text('Total')),
                                    DataColumn(label: Text('Select')),
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

                                      final double total = getItemTotal(item);

                                      return DataRow(
                                        color: WidgetStateProperty.resolveWith<
                                            Color?>(
                                          (states) {
                                            if (selectedItems[index]) {
                                              return cancelPizzaOrange
                                                  .withValues(alpha: 0.12);
                                            }

                                            if (index.isEven) {
                                              return Colors.white;
                                            }

                                            return cancelCreamBackground;
                                          },
                                        ),
                                        cells: [
                                          DataCell(
                                            Text('${index + 1}'),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 190,
                                              child: Text(
                                                itemName,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(formatPrice(quantity)),
                                          ),
                                          DataCell(
                                            Text(
                                              'Rs. ${formatPrice(price)}',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              'Rs. ${formatPrice(total)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: buildSelectionCircle(
                                                selected: selectedItems[index],
                                                onTap: () {
                                                  selectItem(
                                                    index,
                                                    !selectedItems[index],
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
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

            const SizedBox(height: 18),

            // Grand total area.
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 14,
              ),
              decoration: BoxDecoration(
                color: cancelCreamBackground,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.orange.shade100,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: cancelPizzaRed,
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cancelDarkText,
                      ),
                    ),
                  ),
                  Text(
                    'Rs. ${formatPrice(grandTotal)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cancelPizzaRed,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Confirm button retains the existing cancellation action.
            SizedBox(
              width: double.infinity,
              height: 49,
              child: ElevatedButton.icon(
                onPressed: isDeleting
                    ? null
                    : () {
                        confirmDelete(data);
                      },
                icon: isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.delete_outline_rounded,
                        size: 21,
                      ),
                label: Text(
                  isDeleting ? 'Processing...' : 'Confirm Cancellation',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cancelPizzaRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.shade200,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
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
