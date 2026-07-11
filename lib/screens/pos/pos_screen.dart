import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/print_helper.dart';
import 'widgets/cart_item_tile.dart';
import 'widgets/checkout_dialog.dart';
import 'widgets/park_recall_dialog.dart';
import 'widgets/quick_add_dialog.dart';
import 'widgets/add_product_dialog.dart';
import 'widgets/numeric_keypad.dart';

class POSScreen extends StatefulWidget {
  final String userRole;
  final String username;
  final bool isActive;

  const POSScreen({
    super.key,
    required this.userRole,
    required this.username,
    this.isActive = true,
  });

  @override
  State<POSScreen> createState() => POSScreenState();
}

class POSScreenState extends State<POSScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _showSuggestions = false;
  int _quantity = 1;
  final TextEditingController _qtyController = TextEditingController();
  final FocusNode _qtyFocus = FocusNode();

  DateTime? _lastScanTime;
  static const _beepChannel = MethodChannel('com.example.archer_pos/beep');

  // Camera Barcode Scanner State
  bool _isCameraActive = false;
  bool _cameraSettingEnabled = true;
  MobileScannerController? _scannerController;

  Future<void> _playBeep() async {
    try {
      await _beepChannel.invokeMethod('playBeep');
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void initState() {
    super.initState();
    _qtyController.text = '$_quantity';
    _qtyFocus.addListener(_onQtyFocusChange);
    _searchFocus.addListener(_onSearchFocusChange);
    _loadSuggestions();
    _loadScannerSetting();
  }

  Future<void> _loadScannerSetting() async {
    final val = await DatabaseHelper.instance.getSetting('camera_barcode_enabled');
    if (mounted) {
      setState(() {
        _cameraSettingEnabled = val != 'false';
      });
    }
  }

  void _onSearchFocusChange() {
    if (mounted) setState(() {});
  }



  void _onQtyFocusChange() {
    if (!_qtyFocus.hasFocus) {
      final parsed = int.tryParse(_qtyController.text);
      if (parsed == null || parsed <= 0) {
        _qtyController.text = '$_quantity';
      } else {
        setState(() {
          _quantity = parsed.clamp(1, 9999);
          _qtyController.text = '$_quantity';
        });
      }
    }
  }

  void _updateQuantity(int newQty) {
    final clamped = newQty.clamp(1, 9999);
    setState(() {
      _quantity = clamped;
      _qtyController.text = '$clamped';
    });
  }

  Future<void> _showMainQtyDialog() async {
    final ctrl = TextEditingController(text: '$_quantity');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Set Quantity',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              readOnly: true,
              showCursor: true,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            NumericKeypad(
              controller: ctrl,
              isDecimal: false,
              onSubmit: () {
                final parsed = int.tryParse(ctrl.text);
                if (parsed != null && parsed >= 1) {
                  Navigator.of(ctx).pop(parsed);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Minimum quantity is 1')),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(ctrl.text);
              if (parsed != null && parsed >= 1) {
                Navigator.of(ctx).pop(parsed);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result != null) {
      _updateQuantity(result);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.removeListener(_onSearchFocusChange);
    _searchFocus.dispose();
    _qtyController.dispose();
    _qtyFocus.removeListener(_onQtyFocusChange);
    _qtyFocus.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _toggleCamera() async {
    if (_isCameraActive) {
      setState(() {
        _isCameraActive = false;
      });
      _scannerController?.dispose();
      _scannerController = null;
    } else {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        setState(() {
          _isCameraActive = true;
          _scannerController = MobileScannerController(
            formats: [
              BarcodeFormat.ean8,
              BarcodeFormat.ean13,
              BarcodeFormat.code39,
              BarcodeFormat.code128,
              BarcodeFormat.upcA,
              BarcodeFormat.upcE,
            ],
          );
        });
      } else {
        _showSnackBar('Camera permission is required to scan barcodes.', isError: true);
      }
    }
  }

  void _onBarcodeScanned(String code) {
    final now = DateTime.now();
    if (_lastScanTime != null && now.difference(_lastScanTime!) < const Duration(seconds: 2)) {
      return;
    }
    _lastScanTime = now;
    _playBeep();
    _addItemByBarcode(code);
    _showSnackBar('Scanned: $code');
  }

  Widget _buildCameraScannerWidget() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _onBarcodeScanned(rawValue);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 1000),
                    alignment: Alignment.center,
                    child: Container(
                      height: 2,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: _scannerController != null
                      ? ValueListenableBuilder(
                          valueListenable: _scannerController!,
                          builder: (context, state, child) {
                            final torchState = state.torchState;
                            switch (torchState) {
                              case TorchState.off:
                                return const Icon(Icons.flash_off, size: 18);
                              case TorchState.on:
                                return const Icon(Icons.flash_on, size: 18);
                              case TorchState.unavailable:
                                return const Icon(Icons.flash_off, size: 18);
                              case TorchState.auto:
                                return const Icon(Icons.flash_auto, size: 18);
                            }
                          },
                        )
                      : const Icon(Icons.flash_off, size: 18),
                  onPressed: () => _scannerController?.toggleTorch(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _toggleCamera,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Point camera at a barcode',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void refresh() {
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final products = await DatabaseHelper.instance.getProducts(limit: 100);
    if (mounted) setState(() => _searchSuggestions = products);
  }

  Future<void> _onSearchQueryChanged(String val, StateSetter setStateSearchBar) async {
    final query = val.trim();
    if (query.isEmpty) {
      final products = await DatabaseHelper.instance.getProducts(limit: 100);
      if (mounted) {
        setState(() {
          _searchSuggestions = products;
          _showSuggestions = false;
        });
        setStateSearchBar(() {});
      }
      return;
    }

    final terms = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final products = await DatabaseHelper.instance.getProductsByTerms(terms, limit: 100);
    
    if (mounted) {
      setState(() {
        _searchSuggestions = products;
        _showSuggestions = true;
      });
      setStateSearchBar(() {});
    }
  }

  List<Map<String, dynamic>> _getFilteredSuggestionsForQuery(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return [];
    
    final matches = _searchSuggestions
        .where((p) {
          final id = (p['id'] as String).toLowerCase();
          final name = (p['name'] as String).toLowerCase();
          return terms.every((term) => id.contains(term) || name.contains(term));
        })
        .toList();

    // Sort matches by relevance score
    matches.sort((a, b) {
      final aName = (a['name'] as String).toLowerCase();
      final bName = (b['name'] as String).toLowerCase();
      
      final aScore = _calculateRelevanceScore(aName, q, terms);
      final bScore = _calculateRelevanceScore(bName, q, terms);
      
      if (aScore != bScore) {
        return bScore.compareTo(aScore); // Higher score first
      }
      
      return aName.compareTo(bName);
    });

    return matches;
  }

  int _calculateRelevanceScore(String name, String query, List<String> terms) {
    int score = 0;
    
    if (name == query) {
      score += 10000;
    }
    
    if (name.startsWith(query)) {
      score += 5000;
    }
    
    final words = name.split(RegExp(r'\s+'));
    bool wordStartsWithQuery = false;
    int wordMatchCount = 0;
    for (final word in words) {
      if (word.startsWith(query)) {
        wordStartsWithQuery = true;
      }
      for (final term in terms) {
        if (word == term) {
          wordMatchCount += 2;
        } else if (word.startsWith(term)) {
          wordMatchCount += 1;
        }
      }
    }
    
    if (wordStartsWithQuery) {
      score += 2000;
    }
    
    score += wordMatchCount * 100;
    
    return score;
  }

  List<Map<String, dynamic>> get _filteredSuggestions {
    return _getFilteredSuggestionsForQuery(_searchController.text).take(8).toList();
  }

  Future<void> _addItemByBarcode(String input) async {
    final cart = context.read<CartProvider>();
    String barcode = input.trim();
    int qty = _quantity;

    // Handle qty*barcode or barcode*qty syntax
    if (barcode.contains('*')) {
      final parts = barcode.split('*');
      if (parts.length == 2) {
        final firstIsNum = int.tryParse(parts[0]) != null;
        if (firstIsNum) {
          qty = int.parse(parts[0]);
          barcode = parts[1];
        } else {
          barcode = parts[0];
          qty = int.tryParse(parts[1]) ?? qty;
        }
      }
    }

    final product = await DatabaseHelper.instance.getProductById(barcode);

    if (product == null) {
      // Try name search
      final byName = _searchSuggestions.where(
        (p) => (p['name'] as String).toLowerCase() == barcode.toLowerCase(),
      ).toList();
      if (byName.isNotEmpty) {
        await _addProductToCart(byName.first, qty.toDouble());
      } else {
        final suggestions = _getFilteredSuggestionsForQuery(barcode);
        if (suggestions.isNotEmpty) {
          await _addProductToCart(suggestions.first, qty.toDouble());
        } else {
          await _handleProductNotFound(barcode);
        }
      }
    } else {
      await _addProductToCart(product, qty.toDouble());
    }

    _searchController.clear();
    setState(() => _showSuggestions = false);
    _updateQuantity(1);
    _searchFocus.requestFocus();
  }

  Future<void> _addProductToCart(Map<String, dynamic> product, double qty) async {
    final cart = context.read<CartProvider>();
    // Get bundles for this product
    final bundles = await DatabaseHelper.instance.getBundlesForProduct(product['id'] as String);
    cart.addItem(product, qty, cart.pricingMode, bundles: bundles);
  }

  Future<void> _handleProductNotFound(String barcode) async {
    if (widget.userRole != 'admin') {
      _showSnackBar('Product not found. Only admins can add new products.', isError: true);
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AddProductDialog(initialBarcode: barcode),
    );

    if (result != null && mounted) {
      final success = await DatabaseHelper.instance.insertProduct(result);
      if (success) {
        await DatabaseHelper.instance.logAction(
          'PRODUCT_ADDED',
          details: 'Product ${result['name']} added from POS scan',
          userId: widget.username,
        );
        final product = await DatabaseHelper.instance.getProductById(result['id'] as String);
        if (product != null) {
          await _addProductToCart(product, 1);
          _showSnackBar('Product added to inventory and cart!');
          await _loadSuggestions();
        }
      }
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: isError ? kErrorColor : kSuccessColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<bool> _verifyAdmin() async {
    if (widget.userRole == 'admin') return true;
    String? password;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Admin Required'),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Enter Admin Password'),
            onSubmitted: (v) async {
              password = v;
              Navigator.of(ctx).pop(true);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                password = ctrl.text;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (ok == true && password != null) {
      final user = await DatabaseHelper.instance.verifyLogin('admin', password!);
      return user != null;
    }
    return false;
  }

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) {
      _showSnackBar('Cart is empty!', isError: true);
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CheckoutDialog(
        total: cart.total,
        userRole: widget.userRole,
        username: widget.username,
      ),
    );

    if (result != null && mounted) {
      try {
        final saleItems = cart.items.map((item) => {
          'product_id': item.barcode,
          'product_name': item.name,
          'quantity': item.quantity,
          'price': item.price,
        }).toList();

        final saleId = await DatabaseHelper.instance.createSale(
          totalAmount: cart.total,
          amountPaid: result['amount_paid'] as double,
          balanceDue: result['balance_due'] as double,
          customerId: result['customer_id'] as int?,
          items: saleItems,
          payments: [{'method': 'Cash', 'amount': result['amount_paid']}],
          createdBy: widget.username,
        );

        await DatabaseHelper.instance.logAction(
          'POS_SALE',
          details: 'Sale #$saleId - Total: ${formatCurrency(cart.total)} - Paid: ${formatCurrency(result['amount_paid'] as double)}',
          userId: widget.username,
        );

        final customerName = await () async {
          final custId = result['customer_id'] as int?;
          if (custId != null) {
            final c = await DatabaseHelper.instance.getCustomerById(custId);
            return c?['name'] as String?;
          }
          return null;
        }();

        if (mounted) {
          final bool? shouldPrint = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Print Receipt',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
              content: Text(
                'Do you want to print the receipt for Sale #$saleId?',
                style: GoogleFonts.inter(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('No', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextSecondary)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Yes', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );

          if (shouldPrint == true) {
            try {
              await ReceiptPrinter.printReceipt(
                saleId: saleId,
                timestamp: DateTime.now().toIso8601String(),
                cashier: widget.username,
                totalAmount: cart.total,
                amountPaid: result['amount_paid'] as double,
                balanceDue: result['balance_due'] as double,
                customerName: customerName,
                items: saleItems,
              );
            } catch (pe) {
              _showSnackBar('Printing error: $pe', isError: true);
            }
          }
        }

        cart.clearCart();
        _showSnackBar('Sale #$saleId completed successfully! 🎉');
      } catch (e) {
        _showSnackBar('Error processing sale: $e', isError: true);
      }
    }
  }

  Future<void> _parkSale() async {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) {
      _showSnackBar('Nothing to park!', isError: true);
      return;
    }

    String? label;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Park Sale'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Customer Name / Label (optional)',
              hintText: 'e.g. Juan dela Cruz',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                label = ctrl.text.isEmpty ? null : ctrl.text;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Park'),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      await DatabaseHelper.instance.parkSale(label, cart.toJson(), cart.total);
      cart.clearCart();
      _showSnackBar('Sale parked successfully!');
    }
  }

  Future<void> _recallSale() async {
    final parked = await DatabaseHelper.instance.getParkedSales();
    if (!mounted) return;
    if (parked.isEmpty) {
      _showSnackBar('No parked sales found.', isError: true);
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => ParkRecallDialog(
        parkedSales: parked,
        onRecall: (sale) async {
          final cart = context.read<CartProvider>();
          cart.fromJson(sale['cart_data'] as String);
          await DatabaseHelper.instance.deleteParkedSale(sale['id'] as int);
          Navigator.of(ctx).pop();
          _showSnackBar('Sale recalled!');
        },
      ),
    );
  }

  Future<void> _quickAdd() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const QuickAddDialog(),
    );
    if (result != null && mounted) {
      final cart = context.read<CartProvider>();
      cart.addItem({
        'id': 'CUSTOM-${DateTime.now().millisecondsSinceEpoch}',
        'name': result['name'],
        'price': result['price'],
        'wholesale_price': result['price'],
        'cost': 0.0,
      }, result['quantity'] as double, cart.pricingMode, bundles: []);
      await DatabaseHelper.instance.logAction(
        'POS_QUICK_ADD',
        details: 'Quick Add: ${result['name']} x${result['quantity']} @ ${formatCurrency(result['price'] as double)}',
        userId: widget.username,
      );
    }
  }

  Future<bool> _confirmClearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Cart',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: kErrorColor,
          ),
        ),
        content: Text(
          'Are you sure you want to clear all items from the cart?',
          style: GoogleFonts.inter(fontSize: 14, color: kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kErrorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Clear',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 768;
        return isTablet ? _buildTabletLayout(constraints) : _buildPhoneLayout();
      },
    );
  }

  Widget _buildPhoneLayout() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildSearchBar(),
          if (_isCameraActive) _buildCameraScannerWidget(),
          _buildCartList(flex: 1),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BoxConstraints constraints) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final summaryWidth = (constraints.maxWidth * 0.38).clamp(340.0, 440.0);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildSearchBar(),
                if (_isCameraActive) _buildCameraScannerWidget(),
                Expanded(child: _buildCartTable()),
              ],
            ),
          ),
          Container(
            width: summaryWidth,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(left: BorderSide(color: cs.onSurface.withOpacity(0.08))),
            ),
            child: _buildOrderSummaryPanel(),
          ),
        ],
      ),
    );
  }



  Widget _buildSearchBar() {
    return StatefulBuilder(
      builder: (context, setStateSearchBar) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            // Switch to 2-row layout if screen/column width is narrow to prevent horizontal overflow
            final isNarrowLayout = screenWidth < 550;
            final isNarrow = screenWidth < 900;

            final theme = Theme.of(context);
            final cs = theme.colorScheme;
            final isDark = theme.brightness == Brightness.dark;

            final searchField = TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: isNarrow
                    ? 'Scan or search...'
                    : 'Scan barcode or type product name...',
                prefixIcon: _cameraSettingEnabled
                    ? IconButton(
                        icon: Icon(
                          _isCameraActive ? Icons.camera : Icons.qr_code_scanner,
                          color: _isCameraActive ? Colors.green : cs.primary,
                        ),
                        onPressed: _toggleCamera,
                      )
                    : Icon(Icons.qr_code_scanner, color: cs.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchQueryChanged('', setStateSearchBar);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              ),
              onChanged: (val) {
                _onSearchQueryChanged(val, setStateSearchBar);
              },
              onSubmitted: _addItemByBarcode,
              style: GoogleFonts.inter(fontSize: 16, color: cs.onSurface),
            );

            final qtySelector = Container(
              width: isNarrowLayout ? double.infinity : 120,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(10),
                color: cs.surface,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _updateQuantity(_quantity - 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Icon(Icons.remove, size: 16, color: cs.onSurface),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      focusNode: _qtyFocus,
                      readOnly: true,
                      showCursor: true,
                      onTap: _showMainQtyDialog,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _updateQuantity(_quantity + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Icon(Icons.add, size: 16, color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            );

            final pricingToggle = Consumer<CartProvider>(
              builder: (ctx, cart, _) {
                final label = cart.pricingMode == 'retail'
                    ? 'RETAIL'
                    : (isNarrow ? 'WHL' : 'WHOLESALE');
                return ElevatedButton.icon(
                  onPressed: () {
                    cart.toggleGlobalPricing();
                    setStateSearchBar(() {});
                  },
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(
                    label,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cart.pricingMode == 'retail'
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 50),
                    maximumSize: const Size(130, 50),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            );

            return Container(
              padding: const EdgeInsets.all(12),
              color: cs.surface,
              child: Column(
                children: [
                  if (isNarrowLayout) ...[
                    searchField,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: qtySelector),
                        const SizedBox(width: 8),
                        Expanded(child: pricingToggle),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 8),
                        qtySelector,
                        const SizedBox(width: 8),
                        pricingToggle,
                      ],
                    ),
                  ],
                  // Suggestions overlay
                  if (_showSuggestions && _filteredSuggestions.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredSuggestions.length,
                        itemBuilder: (ctx, i) {
                          final p = _filteredSuggestions[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.inventory_2, size: 18, color: cs.primary),
                            title: Text(p['name'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
                            subtitle: Text('${p['id']}', style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.55), fontSize: 12)),
                            trailing: Text(formatCurrency((p['price'] as num).toDouble()),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: cs.primary)),
                            onTap: () {
                              _searchController.text = p['id'] as String;
                              setState(() => _showSuggestions = false);
                              _addItemByBarcode(p['id'] as String);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartList({int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Consumer<CartProvider>(
        builder: (ctx, cart, _) {
          if (cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Cart is empty', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Scan a barcode or search for a product',
                      style: GoogleFonts.inter(color: kTextSecondary, fontSize: 14)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            itemCount: cart.items.length,
            itemBuilder: (ctx, i) => CartItemTile(
              item: cart.items[i],
              index: i,
              userRole: widget.userRole,
              username: widget.username,
              onDelete: () async {
                if (await _verifyAdmin()) {
                  cart.removeItem(i);
                  await DatabaseHelper.instance.logAction('POS_DELETE',
                      details: 'Removed ${cart.items.length > i ? cart.items[i].name : "item"} from cart',
                      userId: widget.username);
                } else {
                  _showSnackBar('Admin access required.', isError: true);
                }
              },
              onQtyChanged: (qty) {
                cart.updateQuantity(i, qty);
              },
              onDiscount: (price) async {
                if (await _verifyAdmin()) {
                  cart.applyDiscount(i, price);
                } else {
                  _showSnackBar('Admin access required.', isError: true);
                }
              },
              onTogglePricing: () {
                cart.toggleItemPricing(i);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartTable() {
    return Consumer<CartProvider>(
      builder: (ctx, cart, _) {
        if (cart.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 80,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text('Cart is empty',
                    style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 20)),
              ],
            ),
          );
        }
        return Column(
          children: [
            // Table header
            Container(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              padding: const EdgeInsets.only(left: 16, right: 24, top: 12, bottom: 12),
              child: Row(
                children: [
                  Expanded(flex: 8, child: _headerCell('Product')),
                  Expanded(flex: 4, child: _headerCell('Price', textAlign: TextAlign.end)),
                  Expanded(flex: 5, child: _headerCell('Qty', textAlign: TextAlign.center)),
                  Expanded(flex: 5, child: _headerCell('Total', textAlign: TextAlign.end)),
                  Expanded(flex: 4, child: _headerCell('')),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: cart.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) => CartItemTile(
                  item: cart.items[i],
                  index: i,
                  userRole: widget.userRole,
                  username: widget.username,
                  isTablet: true,
                  onDelete: () async {
                    if (await _verifyAdmin()) {
                      cart.removeItem(i);
                    } else {
                      _showSnackBar('Admin access required.', isError: true);
                    }
                  },
                  onQtyChanged: (qty) => cart.updateQuantity(i, qty),
                  onDiscount: (price) async {
                    if (await _verifyAdmin()) {
                      cart.applyDiscount(i, price);
                    } else {
                      _showSnackBar('Admin access required.', isError: true);
                    }
                  },
                  onTogglePricing: () => cart.toggleItemPricing(i),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _headerCell(String text, {TextAlign textAlign = TextAlign.start}) => Text(
        text,
        textAlign: textAlign,
        style: GoogleFonts.inter(
            fontWeight: FontWeight.w700, fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
      );

  Widget _buildOrderSummaryPanel() {
    return Consumer<CartProvider>(
      builder: (ctx, cart, _) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Order Summary',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 24, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('${cart.items.length} item(s)',
                  style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.55), fontSize: 16)),
              const Divider(height: 24),
              Expanded(
                child: cart.items.isEmpty
                    ? Center(child: Text('No items',
                        style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.4), fontSize: 16)))
                    : ListView.builder(
                        itemCount: cart.items.length,
                        itemBuilder: (ctx, i) {
                          final item = cart.items[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w600,
                                              fontSize: 16, color: cs.onSurface),
                                          maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text('${item.quantity.toStringAsFixed(item.quantity.truncate() == item.quantity ? 0 : 2)} × ${formatCurrency(item.price)}',
                                          style: GoogleFonts.inter(
                                              color: cs.onSurface.withOpacity(0.55), fontSize: 14)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      formatCurrency(item.price * item.quantity),
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700, fontSize: 16, color: cs.primary),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(isDark ? 0.15 : 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900, fontSize: 22,
                            color: cs.onSurface, letterSpacing: 0.5)),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatCurrency(cart.total),
                          textAlign: TextAlign.end,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900, fontSize: 38, color: cs.primary),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _checkout,
                icon: const Icon(Icons.point_of_sale, size: 24),
                label: Text('CHECKOUT',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  minimumSize: const Size.fromHeight(68),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _parkSale,
                      icon: const Icon(Icons.pause, size: 18),
                      label: Text('Park', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _recallSale,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text('Recall', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kSuccessColor,
                        side: const BorderSide(color: kSuccessColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _quickAdd,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Quick Add', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final cart = context.read<CartProvider>();
                        if (cart.items.isEmpty) return;
                        if (await _confirmClearCart()) {
                          if (await _verifyAdmin()) {
                            cart.clearCart();
                          }
                        }
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: Text('Clear', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kErrorColor,
                        side: const BorderSide(color: kErrorColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Consumer<CartProvider>(
      builder: (ctx, cart, _) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: cs.onSurface)),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatCurrency(cart.total),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: cs.primary),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _checkout,
                  icon: const Icon(Icons.point_of_sale, size: 20),
                  label: Text(
                    'CHECKOUT (${cart.items.length} items)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _phoneActionBtn(
                      icon: Icons.add_circle_outline,
                      label: 'Quick Add',
                      color: const Color(0xFF6366F1),
                      onTap: _quickAdd,
                    ),
                    const SizedBox(width: 4),
                    _phoneActionBtn(
                      icon: Icons.pause_circle_outline,
                      label: 'Park Sale',
                      color: const Color(0xFF0284C7),
                      onTap: _parkSale,
                    ),
                    const SizedBox(width: 4),
                    _phoneActionBtn(
                      icon: Icons.play_circle_outline,
                      label: 'Recall',
                      color: const Color(0xFF10B981),
                      onTap: _recallSale,
                    ),
                    const SizedBox(width: 4),
                    _phoneActionBtn(
                      icon: Icons.clear_all,
                      label: 'Clear Cart',
                      color: kErrorColor,
                      onTap: () async {
                        if (cart.items.isEmpty) return;
                        if (await _confirmClearCart()) {
                          if (await _verifyAdmin()) {
                            cart.clearCart();
                            await DatabaseHelper.instance.logAction('POS_VOID_CART',
                                details: 'Cart cleared', userId: widget.username);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _phoneActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 16),
      label: Text(label, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
