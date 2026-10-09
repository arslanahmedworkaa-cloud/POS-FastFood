import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptScreen extends StatefulWidget {
  final int orderNumber;
  final String date;
  final String customerName;
  final List<Map<String, dynamic>> orderItems;
  final double grandTotal;

  final bool isDuplicate;

  const ReceiptScreen({
    super.key,
    required this.orderNumber,
    required this.date,
    required this.customerName,
    required this.orderItems,
    required this.grandTotal,
    this.isDuplicate = false,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  String businessName = '';
  String businessImage = '';
  String businessAddress = '';
  String businessEmail = '';
  String businessPhone = '';

  bool isPrinting = false;

  @override
  void initState() {
    super.initState();
    loadBusiness();
  }

  Future<void> loadBusiness() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final result = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid)
          .get();

      if (!result.exists) {
        return;
      }

      final data = result.data();

      if (data == null || !mounted) {
        return;
      }

      setState(() {
        businessName = data['businessName']?.toString() ?? '';

        businessImage = data['imageUrl']?.toString() ?? '';

        businessAddress = data['address']?.toString() ?? '';

        businessEmail = data['email']?.toString() ?? '';

        businessPhone = data['phone']?.toString() ?? '';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading business: $e',
          ),
        ),
      );
    }
  }

  ImageProvider? getBusinessLogo() {
    if (businessImage.isEmpty) {
      return null;
    }

    try {
      return MemoryImage(
        base64Decode(businessImage),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> completePrintedOrder() async {
    if (widget.isDuplicate) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || widget.orderItems.isEmpty) {
      return;
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      final DocumentReference orderReference =
          firestore.collection('users').doc(user.uid).collection('orders').doc(
                widget.orderNumber.toString(),
              );

      // Save completed order.
      // Daily Cash is calculated from these
      // completed orders.
      await orderReference.set({
        'orderNo': widget.orderNumber,
        'date': widget.date,
        'customerName': widget.customerName,
        'items': widget.orderItems,
        'grandTotal': widget.grandTotal,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('orderNumber')
          .set({
        'lastOrderNumber': widget.orderNumber,
      });

      final QuerySnapshot cartSnapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .get();

      for (final doc in cartSnapshot.docs) {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .doc(doc.id)
            .delete();
      }
    } catch (e) {
      throw Exception(
        'Order could not be saved: $e',
      );
    }
  }

  Future<pw.Document> createPdf() async {
    final pw.Document pdf = pw.Document();

    pw.MemoryImage? pdfLogo;

    if (businessImage.isNotEmpty) {
      try {
        pdfLogo = pw.MemoryImage(
          base64Decode(businessImage),
        );
      } catch (e) {
        pdfLogo = null;
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.SizedBox(
                height: 65,
                child: pw.Stack(
                  children: [
                    if (pdfLogo != null)
                      pw.Positioned(
                        left: 0,
                        top: 0,
                        child: pw.Container(
                          width: 42,
                          height: 42,
                          child: pw.Image(
                            pdfLogo,
                            fit: pw.BoxFit.cover,
                          ),
                        ),
                      ),
                    pw.Center(
                      child: pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          if (businessName.isNotEmpty)
                            pw.Text(
                              businessName,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          pw.SizedBox(
                            height: 9,
                          ),
                          pw.Text(
                            'SALES RECEIPT',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),

              pw.Center(
                child: pw.Text(
                  '--------------------------------',
                ),
              ),

              pw.SizedBox(height: 7),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(widget.date),
                ],
              ),

              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Order No:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    widget.orderNumber.toString(),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 4),

              // Customer name
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Customer:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      widget.customerName.trim().isEmpty
                          ? 'Dear Customer'
                          : widget.customerName,
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              pw.Center(
                child: pw.Text(
                  '--------------------------------',
                ),
              ),

              pw.SizedBox(height: 7),

              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qty',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Price',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Total',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              pw.Divider(),

              ...widget.orderItems.map(
                (item) {
                  final String itemName = item['itemName']?.toString() ?? '';

                  final String size = item['size']?.toString() ?? '';

                  final String quantity = item['quantity']?.toString() ?? '0';

                  final String price = item['price']?.toString() ?? '0';

                  final double total = double.tryParse(
                        item['total']?.toString() ?? '0',
                      ) ??
                      0;

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 5,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Expanded(
                              flex: 4,
                              child: pw.Text(
                                itemName,
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                quantity,
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                'Rs. $price',
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                'Rs. ${total.toStringAsFixed(0)}',
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        if (size.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(
                              top: 3,
                            ),
                            child: pw.Text(
                              'Size: $size',
                              style: const pw.TextStyle(
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              pw.Divider(),

              pw.SizedBox(height: 5),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'GRAND TOTAL',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Rs. ${widget.grandTotal.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              pw.Center(
                child: pw.Text(
                  '--------------------------------',
                ),
              ),

              pw.SizedBox(height: 7),

              if (businessAddress.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    businessAddress,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 10,
                    ),
                  ),
                ),

              pw.SizedBox(height: 4),

              if (businessEmail.isNotEmpty || businessPhone.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Email: $businessEmail | Contact: $businessPhone',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> saveAsPdf(
    BuildContext context,
  ) async {
    try {
      final pw.Document pdf = await createPdf();

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Receipt_Order_${widget.orderNumber}.pdf',
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error creating PDF: $e',
          ),
        ),
      );
    }
  }

  Future<void> printReceipt(
    BuildContext context,
  ) async {
    if (isPrinting) {
      return;
    }

    setState(() {
      isPrinting = true;
    });

    try {
      final pw.Document pdf = await createPdf();

      final bool printed = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return pdf.save();
        },
      );

      if (widget.isDuplicate) {
        if (!context.mounted) {
          return;
        }

        setState(() {
          isPrinting = false;
        });

        return;
      }

      if (printed) {
        await completePrintedOrder();

        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order No. ${widget.orderNumber} completed successfully',
            ),
          ),
        );

        Navigator.pop(context);
      } else {
        if (!context.mounted) {
          return;
        }

        setState(() {
          isPrinting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Printing cancelled. Order was not completed.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      setState(() {
        isPrinting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error printing receipt: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider? logo = getBusinessLogo();

    final String customerName = widget.customerName.trim().isEmpty
        ? 'Dear Customer'
        : widget.customerName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Colors.grey,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 65,
                  child: Stack(
                    children: [
                      if (logo != null)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              5,
                            ),
                            child: Image(
                              image: logo,
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder: (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (businessName.isNotEmpty)
                              Text(
                                businessName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(
                              height: 9,
                            ),
                            const Text(
                              'SALES RECEIPT',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  '--------------------------------',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Date:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(widget.date),
                  ],
                ),

                const SizedBox(height: 5),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order No:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.orderNumber.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                // Customer Name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        customerName,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                const Text(
                  '--------------------------------',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                const Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Item',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Price',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Total',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(),

                ...widget.orderItems.map(
                  (item) {
                    final String itemName = item['itemName']?.toString() ?? '';

                    final String size = item['size']?.toString() ?? '';

                    final String quantity = item['quantity']?.toString() ?? '0';

                    final String price = item['price']?.toString() ?? '0';

                    final double total = double.tryParse(
                          item['total']?.toString() ?? '0',
                        ) ??
                        0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  itemName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  quantity,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Rs. $price',
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Rs. ${total.toStringAsFixed(0)}',
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          if (size.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 3,
                              ),
                              child: Text(
                                'Size: $size',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                const Divider(),

                const SizedBox(height: 5),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GRAND TOTAL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rs. ${widget.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const Text(
                  '--------------------------------',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 7),

                if (businessAddress.isNotEmpty)
                  Text(
                    businessAddress,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                const SizedBox(height: 5),

                if (businessEmail.isNotEmpty || businessPhone.isNotEmpty)
                  Text(
                    'Email: $businessEmail | Contact: $businessPhone',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),

                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isPrinting
                        ? null
                        : () {
                            saveAsPdf(context);
                          },
                    icon: const Icon(
                      Icons.picture_as_pdf,
                    ),
                    label: const Text(
                      'Save as PDF',
                      style: TextStyle(
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isPrinting
                        ? null
                        : () {
                            printReceipt(
                              context,
                            );
                          },
                    icon: isPrinting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.print,
                          ),
                    label: Text(
                      isPrinting ? 'Printing...' : 'Print Receipt',
                      style: const TextStyle(
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
