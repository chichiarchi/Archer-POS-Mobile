import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class EscPosGenerator {
  final List<int> bytes = [];

  void init() {
    bytes.addAll([0x1B, 0x40]); // ESC @ (Initialize printer)
  }

  void reset() {
    bytes.clear();
  }

  void text(String text, {bool bold = false, int align = 0, bool doubleHeight = false, bool doubleWidth = false}) {
    // Alignment: 0 = Left, 1 = Center, 2 = Right
    bytes.addAll([0x1B, 0x61, align]);
    
    // Bold
    bytes.addAll([0x1B, 0x45, bold ? 1 : 0]);

    // Font size / height / width
    int size = 0;
    if (doubleWidth) size |= 0x20;
    if (doubleHeight) size |= 0x10;
    bytes.addAll([0x1D, 0x21, size]);

    // Add text bytes
    bytes.addAll(utf8.encode(text));
    
    // Reset styles to default
    bytes.addAll([0x1B, 0x45, 0]); // bold off
    bytes.addAll([0x1D, 0x21, 0]); // size normal
  }

  void line(String text, {bool bold = false, int align = 0, bool doubleHeight = false, bool doubleWidth = false}) {
    this.text(text + '\n', bold: bold, align: align, doubleHeight: doubleHeight, doubleWidth: doubleWidth);
  }

  void feed(int lines) {
    bytes.addAll([0x1B, 0x64, lines]); // ESC d (Feed lines)
  }

  void cut() {
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // GS V 66 0 (Feed and half cut)
  }
}

class ReceiptPrinter {
  static const _printerChannel = MethodChannel('com.example.archer_pos/printer');

  static Future<void> printReceipt({
    required int saleId,
    required String timestamp,
    required String cashier,
    required double totalAmount,
    required double amountPaid,
    required double balanceDue,
    required String? customerName,
    required List<Map<String, dynamic>> items,
  }) async {
    final gen = EscPosGenerator();
    gen.init();

    // 58mm printer has 32 columns wide using Font A (standard)
    
    // Title centered, bold, tall size (no double-width to avoid wrapping on 58mm paper)
    gen.line('ARCHERMART', bold: true, align: 1, doubleHeight: true);
    gen.line('--------------------------------', align: 1); // 32 characters

    // Metadata
    gen.line('Sale ID: #$saleId');
    String dateStr = timestamp;
    try {
      dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(timestamp));
    } catch (_) {}
    gen.line('Date: $dateStr');
    gen.line('Cashier: $cashier');
    if (customerName != null && customerName.trim().isNotEmpty) {
      gen.line('Customer: $customerName');
    }
    gen.line('--------------------------------', align: 1);

    // Items Header
    gen.line('Qty  Item                  Price', bold: true);
    gen.line('--------------------------------', align: 1);

    // Items
    for (final item in items) {
      final qty = (item['quantity'] as num).toDouble();
      final price = (item['price'] as num).toDouble();
      final name = item['product_name'] as String;

      // Layout columns:
      // Qty is 4 chars (e.g. "1x  ")
      // Price is 8 chars (e.g. "  500.00")
      // Name gets remaining 20 chars
      final qtyStr = '${qty.toStringAsFixed(0)}x  '.padRight(4);
      final priceStr = (qty * price).toStringAsFixed(2).padLeft(8);
      
      String nameStr = name;
      if (nameStr.length > 20) {
        nameStr = nameStr.substring(0, 17) + '...';
      } else {
        nameStr = nameStr.padRight(20);
      }
      
      gen.line('$qtyStr$nameStr$priceStr');
    }
    gen.line('--------------------------------', align: 1);

    // Totals
    final change = amountPaid > totalAmount ? amountPaid - totalAmount : 0.0;
    
    // Total line bold
    gen.line('TOTAL DUE:      ${totalAmount.toStringAsFixed(2).padLeft(16)}', bold: true);
    gen.line('Amount Paid:    ${amountPaid.toStringAsFixed(2).padLeft(16)}');
    if (balanceDue > 0) {
      gen.line('Balance Due:    ${balanceDue.toStringAsFixed(2).padLeft(16)}', bold: true);
    } else {
      gen.line('Change:         ${change.toStringAsFixed(2).padLeft(16)}');
    }
    
    gen.line('--------------------------------', align: 1);
    gen.line('Thank you for your purchase!', align: 1);
    gen.feed(3);
    gen.cut();

    final bytes = Uint8List.fromList(gen.bytes);
    await _printerChannel.invokeMethod('printRaw', {'bytes': bytes});
  }
}
