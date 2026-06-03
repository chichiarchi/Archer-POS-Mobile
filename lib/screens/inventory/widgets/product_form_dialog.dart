import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/constants.dart';

class ProductFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;

  const ProductFormDialog({super.key, this.initialProduct});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _barcodeController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _retailPriceController = TextEditingController();
  final TextEditingController _wholesalePriceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  bool get _isEditMode => widget.initialProduct != null;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(
      text: _isEditMode ? widget.initialProduct!['id'] as String? ?? '' : '',
    );
    if (_isEditMode) {
      _nameController.text = widget.initialProduct!['name'] as String? ?? '';
      _costController.text = (widget.initialProduct!['cost'] as num?)?.toString() ?? '0.0';
      _retailPriceController.text = (widget.initialProduct!['price'] as num?)?.toString() ?? '0.0';
      _wholesalePriceController.text = (widget.initialProduct!['wholesale_price'] as num?)?.toString() ?? '0.0';
      _categoryController.text = widget.initialProduct!['category'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _costController.dispose();
    _retailPriceController.dispose();
    _wholesalePriceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'id': _barcodeController.text.trim(),
        'name': _nameController.text.trim(),
        'cost': double.tryParse(_costController.text.trim()) ?? 0.0,
        'price': double.tryParse(_retailPriceController.text.trim()) ?? 0.0,
        'wholesale_price': double.tryParse(_wholesalePriceController.text.trim()) ?? 0.0,
        'category': _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditMode ? 'Edit Product Details' : 'Add New Product',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Barcode
                TextFormField(
                  controller: _barcodeController,
                  enabled: !_isEditMode,
                  decoration: InputDecoration(
                    labelText: 'Barcode *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.qr_code),
                    fillColor: _isEditMode ? Colors.grey.withOpacity(0.1) : null,
                    filled: _isEditMode,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Barcode is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Product Name *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Product Name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Category
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // Cost Price
                TextFormField(
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cost Price (₱)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.money),
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final c = double.tryParse(val);
                      if (c == null || c < 0) {
                        return 'Enter a valid positive cost price.';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Retail Price
                TextFormField(
                  controller: _retailPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Retail Price (₱) *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Retail price is required.';
                    }
                    final p = double.tryParse(val);
                    if (p == null || p <= 0) {
                      return 'Retail price must be greater than 0.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Wholesale Price
                TextFormField(
                  controller: _wholesalePriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Wholesale Price (₱) (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.sell_outlined),
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final p = double.tryParse(val);
                      if (p == null || p < 0) {
                        return 'Enter a valid positive wholesale price.';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: kTextSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Save Product',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
