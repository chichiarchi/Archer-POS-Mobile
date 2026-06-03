import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import 'widgets/cart_item_tile.dart';
import 'widgets/checkout_dialog.dart';
import 'widgets/park_recall_dialog.dart';
import 'widgets/quick_add_dialog.dart';
import 'widgets/add_product_dialog.dart';

class POSScreen extends StatefulWidget {
  final String userRole;
  final String username;

  const POSScreen({super.key, required this.userRole, required this.username});

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

  @override
  void initState() {
    super.initState();
    _qtyController.text = '$_quantity';
    _qtyFocus.addListener(_onQtyFocusChange);
    _loadSuggestions();
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _qtyController.dispose();
    _qtyFocus.removeListener(_onQtyFocusChange);
    _qtyFocus.dispose();
    super.dispose();
  }

  void refresh() {
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final products = await DatabaseHelper.instance.getProducts(limit: 500);
    if (mounted) setState(() => _searchSuggestions = products);
  }

  List<Map<String, dynamic>> get _filteredSuggestions {
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) return [];
    return _searchSuggestions
        .where((p) =>
            (p['id'] as String).toLowerCase().contains(q) ||
            (p['name'] as String).toLowerCase().contains(q))
        .take(8)
        .toList();
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
        await _handleProductNotFound(barcode);
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
      backgroundColor: kBackgroundColor,
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCartList(flex: 1),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BoxConstraints constraints) {
    // Use 35% of screen width for summary panel, clamped between 285 and 360px
    final summaryWidth = (constraints.maxWidth * 0.35).clamp(285.0, 360.0);
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Row(
        children: [
          // Left: Cart
          Expanded(
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(child: _buildCartTable()),
                _buildCartActionButtons(),
              ],
            ),
          ),
          // Right: Order Summary
          Container(
            width: summaryWidth,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: _buildOrderSummaryPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // Switch to 2-row layout if screen/column width is narrow to prevent horizontal overflow
        final isNarrowLayout = screenWidth < 550;
        final isNarrow = screenWidth < 900;

        final searchField = TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          decoration: InputDecoration(
            hintText: isNarrow
                ? 'Scan or search...'
                : 'Scan barcode or type product name...',
            prefixIcon: const Icon(Icons.qr_code_scanner, color: kPrimaryColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _showSuggestions = false);
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kPrimaryColor, width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
          onChanged: (val) {
            setState(() => _showSuggestions = val.isNotEmpty);
          },
          onSubmitted: _addItemByBarcode,
          style: GoogleFonts.inter(fontSize: 16),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-_.*]'))],
        );

        final qtySelector = Container(
          width: isNarrowLayout ? double.infinity : 120,
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: kBorderColor),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _updateQuantity(_quantity - 1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Icon(Icons.remove, size: 16, color: kTextPrimary),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  focusNode: _qtyFocus,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed > 0) {
                      _quantity = parsed.clamp(1, 9999);
                    }
                  },
                  onSubmitted: (val) {
                    final parsed = int.tryParse(val) ?? 1;
                    _updateQuantity(parsed);
                  },
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _updateQuantity(_quantity + 1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Icon(Icons.add, size: 16, color: kTextPrimary),
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
                setState(() {});
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
          color: Colors.white,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredSuggestions.length,
                    itemBuilder: (ctx, i) {
                      final p = _filteredSuggestions[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.inventory_2, size: 18, color: kPrimaryColor),
                        title: Text(p['name'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('${p['id']}', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 12)),
                        trailing: Text(formatCurrency((p['price'] as num).toDouble()),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kPrimaryColor)),
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
                Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Cart is empty', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 20)),
              ],
            ),
          );
        }
        return Column(
          children: [
            // Table header
            Container(
              color: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _headerCell('Product')),
                  Expanded(flex: 2, child: _headerCell('Pricing', textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: _headerCell('Price', textAlign: TextAlign.end)),
                  Expanded(flex: 2, child: _headerCell('Qty', textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: _headerCell('Total', textAlign: TextAlign.end)),
                  Expanded(flex: 1, child: _headerCell('')),
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
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: kTextSecondary),
      );

  Widget _buildCartActionButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _actionBtn('Quick Add', Icons.add_circle_outline, const Color(0xFF6366F1), _quickAdd),
          _actionBtn('Park Sale', Icons.pause_circle_outline, const Color(0xFF0284C7), _parkSale),
          _actionBtn('Recall', Icons.play_circle_outline, const Color(0xFF10B981), _recallSale),
          _actionBtn('Clear Cart', Icons.clear_all, kErrorColor, () async {
            final cart = context.read<CartProvider>();
            if (cart.items.isEmpty) return;
            if (await _confirmClearCart()) {
              if (await _verifyAdmin()) {
                cart.clearCart();
                await DatabaseHelper.instance.logAction('POS_VOID_CART',
                    details: 'Cart cleared', userId: widget.username);
              }
            }
          }),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      label: Text(label, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildOrderSummaryPanel() {
    return Consumer<CartProvider>(
      builder: (ctx, cart, _) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Order Summary', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: kTextPrimary)),
              const SizedBox(height: 4),
              Text('${cart.items.length} item(s)', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 14)),
              const Divider(height: 24),
              Expanded(
                child: cart.items.isEmpty
                    ? Center(child: Text('No items', style: GoogleFonts.inter(color: kTextSecondary)))
                    : ListView.builder(
                        itemCount: cart.items.length,
                        itemBuilder: (ctx, i) {
                          final item = cart.items[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      Text('${item.quantity.toStringAsFixed(item.quantity.truncate() == item.quantity ? 0 : 2)} × ${formatCurrency(item.price)}',
                                          style: GoogleFonts.inter(color: kTextSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text(formatCurrency(item.price * item.quantity),
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: kPrimaryColor)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: kTextPrimary)),
                  Text(formatCurrency(cart.total),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 24, color: kPrimaryColor)),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _checkout,
                icon: const Icon(Icons.point_of_sale, size: 22),
                label: Text('CHECKOUT', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _parkSale,
                      icon: const Icon(Icons.pause, size: 18),
                      label: Text('Park', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _recallSale,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text('Recall', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kSuccessColor,
                        side: const BorderSide(color: kSuccessColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      label: Text('Quick Add', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      label: Text('Clear', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kErrorColor,
                        side: const BorderSide(color: kErrorColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      builder: (ctx, cart, _) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: kTextPrimary)),
                  Text(formatCurrency(cart.total),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: kPrimaryColor)),
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
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
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
      ),
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
