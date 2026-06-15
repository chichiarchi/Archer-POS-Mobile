import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';

class BundleManageDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final String username;

  const BundleManageDialog({
    super.key,
    required this.productId,
    required this.productName,
    required this.username,
  });

  @override
  State<BundleManageDialog> createState() => _BundleManageDialogState();
}

class _BundleManageDialogState extends State<BundleManageDialog> {
  List<Map<String, dynamic>> _bundles = [];
  bool _isLoading = false;

  // Form controllers for adding/editing a bundle inline/in sub-dialog
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _wholesalePriceController =
      TextEditingController();
  final TextEditingController _costController = TextEditingController();

  Map<String, dynamic>? _editingBundle;

  @override
  void initState() {
    super.initState();
    _loadBundles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _wholesalePriceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _loadBundles() async {
    setState(() => _isLoading = true);
    try {
      final list =
          await DatabaseHelper.instance.getBundlesForProduct(widget.productId);
      setState(() {
        _bundles = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading bundles: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? kErrorColor : kSuccessColor,
      ),
    );
  }

  void _openBundleForm([Map<String, dynamic>? bundle]) {
    _editingBundle = bundle;
    if (bundle != null) {
      _nameController.text = bundle['bundle_name'] as String? ?? '';
      _qtyController.text = (bundle['quantity'] as num?)?.toString() ?? '1.0';
      _priceController.text = (bundle['price'] as num?)?.toString() ?? '0.0';
      _wholesalePriceController.text =
          (bundle['wholesale_price'] as num?)?.toString() ?? '0.0';
      _costController.text = (bundle['cost'] as num?)?.toString() ?? '0.0';
    } else {
      _nameController.clear();
      _qtyController.text = '10.0';
      _priceController.clear();
      _wholesalePriceController.clear();
      _costController.clear();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(bundle != null ? 'Edit Bundle' : 'Add New Bundle'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Bundle Name (e.g., Dozen, Pack of 10) *'),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Quantity (units in bundle) *'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final q = double.tryParse(val);
                    if (q == null || q <= 0) return 'Must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _costController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Cost Price of Bundle (₱)'),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final c = double.tryParse(val);
                      if (c == null || c < 0) return 'Must be positive';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Retail Price of Bundle (₱) *'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final p = double.tryParse(val);
                    if (p == null || p <= 0) return 'Must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _wholesalePriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Wholesale Price of Bundle (₱)'),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final p = double.tryParse(val);
                      if (p == null || p < 0) return 'Must be positive';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _saveBundle(ctx),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBundle(BuildContext dialogContext) async {
    if (!_formKey.currentState!.validate()) return;

    final bundleData = {
      'product_id': widget.productId,
      'bundle_name': _nameController.text.trim(),
      'quantity': double.parse(_qtyController.text.trim()),
      'price': double.parse(_priceController.text.trim()),
      'wholesale_price':
          double.tryParse(_wholesalePriceController.text.trim()) ?? 0.0,
      'cost': double.tryParse(_costController.text.trim()) ?? 0.0,
    };

    try {
      bool success = false;
      if (_editingBundle == null) {
        success = await DatabaseHelper.instance.insertBundle(bundleData);
        if (success) {
          await DatabaseHelper.instance.logAction(
            kActionBundleAdded,
            details:
                'Added bundle "${bundleData['bundle_name']}" to product ${widget.productId}',
            userId: widget.username,
          );
        }
      } else {
        final id = _editingBundle!['id'] as int;
        success = await DatabaseHelper.instance.updateBundle(id, bundleData);
        if (success) {
          await DatabaseHelper.instance.logAction(
            kActionBundleEdited,
            details: 'Updated bundle "$id" for product ${widget.productId}',
            userId: widget.username,
          );
        }
      }

      if (success) {
        _showSnackBar('Bundle saved successfully!');
        Navigator.of(dialogContext).pop();
        _loadBundles();
      } else {
        _showSnackBar('Failed to save bundle.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error saving bundle: $e', isError: true);
    }
  }

  Future<void> _deleteBundle(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bundle'),
        content: Text('Are you sure you want to delete bundle "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await DatabaseHelper.instance.deleteBundle(id);
        if (success) {
          await DatabaseHelper.instance.logAction(
            kActionBundleDeleted,
            details:
                'Deleted bundle "$id" ($name) for product ${widget.productId}',
            userId: widget.username,
          );
          _showSnackBar('Bundle deleted.');
          _loadBundles();
        } else {
          _showSnackBar('Failed to delete bundle.', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error deleting bundle: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Bundles',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.productName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Existing Bundles (${_bundles.length})',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openBundleForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Bundle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _bundles.isEmpty
                      ? Center(
                          child: Text(
                            'No bundles defined for this product.',
                            style: GoogleFonts.inter(
                                color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _bundles.length,
                          separatorBuilder: (ctx, idx) => const Divider(),
                          itemBuilder: (ctx, index) {
                            final b = _bundles[index];
                            final name = b['bundle_name'] as String? ?? '';
                            final qty =
                                (b['quantity'] as num?)?.toDouble() ?? 0.0;
                            final price =
                                (b['price'] as num?)?.toDouble() ?? 0.0;
                            final wholesale =
                                (b['wholesale_price'] as num?)?.toDouble() ??
                                    0.0;
                            final id = b['id'] as int;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                name,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface),
                              ),
                              subtitle: Text(
                                'Qty: $qty | Retail: ${formatCurrency(price)} | Wholesale: ${formatCurrency(wholesale)}',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: cs.onSurface.withValues(alpha: 0.6)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        color: cs.primary),
                                    onPressed: () => _openBundleForm(b),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: cs.error),
                                    onPressed: () => _deleteBundle(id, name),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
