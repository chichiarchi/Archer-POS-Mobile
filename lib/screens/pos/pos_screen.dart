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

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
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
    setState(() => _quantity = 1);
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

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    return isTablet ? _buildTabletLayout() : _buildPhoneLayout();
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

  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Row(
        children: [
          // Left: Cart
          Expanded(
            flex: 3,
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
            width: 320,
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
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  decoration: InputDecoration(
                    hintText: 'Scan barcode or type product name...',
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
                ),
              ),
              const SizedBox(width: 8),
              // Qty selector
              Container(
                width: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: kBorderColor),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      onPressed: () => setState(() => _quantity = (_quantity - 1).clamp(1, 9999)),
                      padding: EdgeInsets.zero,
                    ),
                    Text('$_quantity', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () => setState(() => _quantity = (_quantity + 1).clamp(1, 9999)),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Pricing mode toggle
              Consumer<CartProvider>(
                builder: (ctx, cart, _) => ElevatedButton.icon(
                  onPressed: () {
                    cart.toggleGlobalPricing();
                    setState(() {});
                  },
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(
                    cart.pricingMode == 'retail' ? 'RETAIL' : 'WHOLESALE',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cart.pricingMode == 'retail'
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(110, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
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
                  Expanded(flex: 1, child: _headerCell('Pricing')),
                  Expanded(flex: 1, child: _headerCell('Price')),
                  Expanded(flex: 1, child: _headerCell('Qty')),
                  Expanded(flex: 1, child: _headerCell('Total')),
                  const SizedBox(width: 80),
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

  Widget _headerCell(String text) => Text(
        text,
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
            if (await _verifyAdmin()) {
              cart.clearCart();
              await DatabaseHelper.instance.logAction('POS_VOID_CART',
                  details: 'Cart cleared', userId: widget.username);
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
                        if (await _verifyAdmin()) {
                          cart.clearCart();
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
        ),
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
                label: Text('CHECKOUT (${cart.items.length} items)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _quickAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Quick Add'),
                ),
                TextButton.icon(
                  onPressed: _parkSale,
                  icon: const Icon(Icons.pause, size: 16),
                  label: const Text('Park'),
                ),
                TextButton.icon(
                  onPressed: _recallSale,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Recall'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
