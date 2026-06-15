import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import 'widgets/product_form_dialog.dart';
import 'widgets/bundle_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InventoryScreen — Product Manager
// ─────────────────────────────────────────────────────────────────────────────

class InventoryScreen extends StatefulWidget {
  final String userRole;
  final String username;

  const InventoryScreen({
    super.key,
    required this.userRole,
    this.username = 'system',
  });

  @override
  State<InventoryScreen> createState() => InventoryScreenState();
}

class InventoryScreenState extends State<InventoryScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  int _currentPage = 0;
  int _totalCount = 0;
  String _searchQuery = '';

  static const int _pageSize = 100;

  bool get _isAdmin => widget.userRole == 'admin';

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Public refresh callable from MainScreen ────────────────────────────────
  void refresh() => _loadProducts();

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final search = _searchQuery.isEmpty ? null : _searchQuery;
      final results = await DatabaseHelper.instance.getProducts(
        search: search,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );
      final count =
          await DatabaseHelper.instance.getProductCount(search: search);
      if (mounted) {
        setState(() {
          _products = results;
          _totalCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading products: $e', isError: true);
      }
    }
  }

  // ── Admin verification ─────────────────────────────────────────────────────
  Future<bool> _verifyAdmin() async {
    if (_isAdmin) return true;
    String? password;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Admin Required',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Admin Password',
              prefixIcon: const Icon(Icons.lock_outline, color: kPrimaryColor),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2),
              ),
            ),
            onSubmitted: (v) {
              password = v;
              Navigator.of(ctx).pop(true);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: kTextSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                password = ctrl.text;
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Confirm',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (ok == true && password != null) {
      final user =
          await DatabaseHelper.instance.verifyLogin('admin', password!);
      return user != null;
    }
    return false;
  }

  // ── CRUD Operations ────────────────────────────────────────────────────────
  Future<void> _addProduct() async {
    if (!_isAdmin) {
      if (!await _verifyAdmin()) {
        _showSnackBar('Admin access required.', isError: true);
        return;
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ProductFormDialog(initialProduct: null),
    );

    if (result != null && mounted) {
      final success = await DatabaseHelper.instance.insertProduct(result);
      if (success) {
        await DatabaseHelper.instance.logAction(
          kActionProductAdded,
          details: 'Product "${result['name']}" (${result['id']}) added',
          userId: widget.username,
        );
        _showSnackBar('Product "${result['name']}" added successfully!');
        _currentPage = 0;
        await _loadProducts();
      } else {
        _showSnackBar('Failed to add product. Barcode may already exist.',
            isError: true);
      }
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    if (!_isAdmin) {
      if (!await _verifyAdmin()) {
        _showSnackBar('Admin access required.', isError: true);
        return;
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductFormDialog(initialProduct: product),
    );

    if (result != null && mounted) {
      final id = product['id'] as String;
      final success = await DatabaseHelper.instance.updateProduct(id, result);
      if (success) {
        await DatabaseHelper.instance.logAction(
          kActionProductUpdated,
          details: 'Product "$id" updated: ${result['name']}',
          userId: widget.username,
        );
        _showSnackBar('Product updated successfully!');
        await _loadProducts();
      } else {
        _showSnackBar('Failed to update product.', isError: true);
      }
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    if (!_isAdmin) {
      if (!await _verifyAdmin()) {
        _showSnackBar('Admin access required.', isError: true);
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Product',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 18, color: kErrorColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete:',
              style: GoogleFonts.inter(color: kTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              product['name'] as String,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: kTextPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Barcode: ${product['id']}',
              style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kErrorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: kErrorColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. Associated bundles will also be deleted.',
                      style:
                          GoogleFonts.inter(color: kErrorColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text('Cancel', style: GoogleFonts.inter(color: kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kErrorColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final id = product['id'] as String;
      final success = await DatabaseHelper.instance.deleteProduct(id);
      if (success) {
        await DatabaseHelper.instance.logAction(
          kActionProductDeleted,
          details: 'Product "$id" (${product['name']}) deleted',
          userId: widget.username,
        );
        _showSnackBar('Product deleted.');
        // Adjust page if needed
        final newTotal = _totalCount - 1;
        final maxPage = newTotal <= 0 ? 0 : ((newTotal - 1) ~/ _pageSize);
        if (_currentPage > maxPage) _currentPage = maxPage;
        await _loadProducts();
      } else {
        _showSnackBar('Failed to delete product.', isError: true);
      }
    }
  }

  Future<void> _manageBundles(Map<String, dynamic> product) async {
    if (!_isAdmin) {
      if (!await _verifyAdmin()) {
        _showSnackBar('Admin access required.', isError: true);
        return;
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BundleManageDialog(
        productId: product['id'] as String,
        productName: product['name'] as String,
        username: widget.username,
      ),
    );

    // Refresh after managing bundles (has_bundle may have changed)
    if (mounted) await _loadProducts();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
      backgroundColor: isError ? kErrorColor : kSuccessColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _onSearchChanged(String value) {
    _searchQuery = value.trim();
    _currentPage = 0;
    _loadProducts();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: theme.colorScheme.primary))
                : _products.isEmpty
                    ? _buildEmptyState()
                    : _buildProductList(),
          ),
          if (_totalCount > 0) _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product Manager',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: cs.onSurface)),
              Text('$_totalCount product${_totalCount == 1 ? '' : 's'} total',
                  style: GoogleFonts.inter(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontSize: 14)),
            ],
          ),
          const Spacer(),
          if (_isAdmin)
            ElevatedButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add, size: 18),
              label: Text('Add Product',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor:
                    isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                elevation: 0,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kWarningColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kWarningColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 14, color: kWarningColor),
                  const SizedBox(width: 4),
                  Text('View Only',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: kWarningColor)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: GoogleFonts.inter(fontSize: 16, color: cs.onSurface),
        decoration: InputDecoration(
          hintText: 'Search by barcode or product name...',
          hintStyle: GoogleFonts.inter(
              color: cs.onSurface.withValues(alpha: 0.4), fontSize: 15),
          prefixIcon: Icon(Icons.search, color: cs.primary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.onSurface.withValues(alpha: 0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.onSurface.withValues(alpha: 0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 80, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No products match your search'
                : 'No products yet',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different keyword or barcode'
                : _isAdmin
                    ? 'Tap "Add Product" to add your first product'
                    : 'Products will appear here once added by an admin',
            style: GoogleFonts.inter(
                fontSize: 15, color: cs.onSurface.withValues(alpha: 0.4)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Product List — phone: card list | tablet: table rows ─────────────────
  Widget _buildProductList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 768;
        if (isTablet) return _buildProductTable();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          itemCount: _products.length,
          itemBuilder: (ctx, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildProductCard(_products[i]),
          ),
        );
      },
    );
  }

  // ── Tablet: table-style list ──────────────────────────────────────────────
  Widget _buildProductTable() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final rowBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final headerStyle = GoogleFonts.inter(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: cs.onSurface.withValues(alpha: 0.55),
      letterSpacing: 0.5,
    );

    return Column(
      children: [
        // Table header
        Container(
          color: headerBg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                  flex: 1,
                  child: Text('#',
                      style: headerStyle, textAlign: TextAlign.center)),
              Expanded(flex: 3, child: Text('PRODUCT', style: headerStyle)),
              Expanded(flex: 2, child: Text('BARCODE', style: headerStyle)),
              Expanded(
                  flex: 2,
                  child: Text('RETAIL',
                      style: headerStyle, textAlign: TextAlign.end)),
              Expanded(
                  flex: 2,
                  child: Text('WHOLESALE',
                      style: headerStyle, textAlign: TextAlign.end)),
              if (_isAdmin)
                Expanded(
                    flex: 2,
                    child: Text('COST',
                        style: headerStyle, textAlign: TextAlign.end)),
              if (_isAdmin)
                Expanded(
                    flex: 2,
                    child: Text('ACTIONS',
                        style: headerStyle, textAlign: TextAlign.center)),
            ],
          ),
        ),
        Container(height: 1, color: rowBorder),
        // Table rows
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _products.length,
            separatorBuilder: (_, __) => Container(height: 1, color: rowBorder),
            itemBuilder: (ctx, i) => _buildTableRow(
                _products[i], i + 1 + (_currentPage * _pageSize)),
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(Map<String, dynamic> product, int rowNum) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasBundle = (product['has_bundle'] as int? ?? 0) == 1;
    final name = product['name'] as String? ?? '';
    final barcode = product['id'] as String? ?? '';
    final retailPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
    final wholesalePrice =
        (product['wholesale_price'] as num?)?.toDouble() ?? 0.0;
    final cost = (product['cost'] as num?)?.toDouble() ?? 0.0;

    return InkWell(
      onTap: _isAdmin ? () => _editProduct(product) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Row(
          children: [
            Expanded(
                flex: 1,
                child: Text(
                  '$rowNum',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: cs.onSurface.withValues(alpha: 0.4)),
                )),
            Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (hasBundle)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Bundle',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF7C3AED),
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                )),
            Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(Icons.qr_code,
                        size: 13, color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(barcode,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: 0.55)),
                            overflow: TextOverflow.ellipsis)),
                  ],
                )),
            Expanded(
                flex: 2,
                child: Text(formatCurrency(retailPrice),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.primary))),
            Expanded(
                flex: 2,
                child: Text(formatCurrency(wholesalePrice),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kSuccessColor))),
            if (_isAdmin)
              Expanded(
                  flex: 2,
                  child: Text(formatCurrency(cost),
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kWarningColor))),
            if (_isAdmin)
              Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tableActionBtn(Icons.edit_outlined, cs.primary,
                          () => _editProduct(product)),
                      const SizedBox(width: 8),
                      _tableActionBtn(
                          Icons.inventory_outlined,
                          const Color(0xFF7C3AED),
                          () => _manageBundles(product)),
                      const SizedBox(width: 8),
                      _tableActionBtn(
                          Icons.delete_outline,
                          const Color(0xFFDC2626),
                          () => _deleteProduct(product)),
                    ],
                  )),
          ],
        ),
      ),
    );
  }

  Widget _tableActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }

  // ── Phone card (kept for phone layout) ───────────────────────────────────
  Widget _buildProductCard(Map<String, dynamic> product) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasBundle = (product['has_bundle'] as int? ?? 0) == 1;
    final name = product['name'] as String? ?? '';
    final barcode = product['id'] as String? ?? '';
    final retailPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
    final wholesalePrice =
        (product['wholesale_price'] as num?)?.toDouble() ?? 0.0;
    final cost = (product['cost'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.15)),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top row: barcode + badge ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code,
                              size: 13,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          Flexible(
                              child: Text(barcode,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.55),
                                      letterSpacing: 0.5),
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(name,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: cs.onSurface),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Bundle badge
                if (hasBundle)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFF6366F1).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_outlined,
                            size: 12, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        Text(
                          'Bundles',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.1)),
            const SizedBox(height: 10),
            // ── Price row ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildPriceChip(
                    label: 'RETAIL',
                    value: formatCurrency(retailPrice),
                    color: kPrimaryColor,
                    bgColor: kPrimaryColor.withValues(alpha: 0.07),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPriceChip(
                    label: 'WHOLESALE',
                    value: formatCurrency(wholesalePrice),
                    color: kSuccessColor,
                    bgColor: kSuccessColor.withValues(alpha: 0.07),
                  ),
                ),
                if (_isAdmin) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPriceChip(
                      label: 'COST',
                      value: formatCurrency(cost),
                      color: kWarningColor,
                      bgColor: kWarningColor.withValues(alpha: 0.07),
                    ),
                  ),
                ],
              ],
            ),
            // ── Action buttons (admin only) ────────────────────────────────
            if (_isAdmin) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.1)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _buildActionButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    color: cs.primary,
                    onTap: () => _editProduct(product),
                  )),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _buildActionButton(
                    label: 'Bundles',
                    icon: Icons.inventory_outlined,
                    color: const Color(0xFF7C3AED),
                    onTap: () => _manageBundles(product),
                  )),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _buildActionButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    color: const Color(0xFFDC2626),
                    onTap: () => _deleteProduct(product),
                  )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceChip({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final totalPages = (_totalCount / _pageSize).ceil();
    final startItem = _currentPage * _pageSize + 1;
    final endItem = ((_currentPage + 1) * _pageSize).clamp(0, _totalCount);
    final hasPrev = _currentPage > 0;
    final hasNext = _currentPage < totalPages - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border:
            Border(top: BorderSide(color: cs.onSurface.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem–$endItem of $_totalCount',
            style: GoogleFonts.inter(
                fontSize: 14, color: cs.onSurface.withValues(alpha: 0.55)),
          ),
          Row(
            children: [
              _paginationBtn(
                  icon: Icons.chevron_left,
                  enabled: hasPrev,
                  cs: cs,
                  onTap: () {
                    if (hasPrev) {
                      setState(() => _currentPage--);
                      _loadProducts();
                    }
                  }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('Page ${_currentPage + 1} / $totalPages',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
              ),
              _paginationBtn(
                  icon: Icons.chevron_right,
                  enabled: hasNext,
                  cs: cs,
                  onTap: () {
                    if (hasNext) {
                      setState(() => _currentPage++);
                      _loadProducts();
                    }
                  }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paginationBtn({
    required IconData icon,
    required bool enabled,
    required ColorScheme cs,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color:
              enabled ? cs.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? cs.primary.withValues(alpha: 0.3)
                : cs.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Icon(icon,
            size: 22,
            color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.3)),
      ),
    );
  }
}
