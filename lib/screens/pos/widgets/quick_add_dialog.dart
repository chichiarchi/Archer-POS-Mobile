import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'numeric_keypad.dart';

class QuickAddDialog extends StatefulWidget {
  const QuickAddDialog({super.key});

  @override
  State<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<QuickAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1.0');
  
  late TextEditingController _activeController;

  @override
  void initState() {
    super.initState();
    _activeController = _priceController;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'name': _nameController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'quantity': double.tryParse(_qtyController.text.trim()) ?? 1.0,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Quick Add Custom Item',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Name field
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter an item name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Price field
                TextFormField(
                  controller: _priceController,
                  readOnly: true,
                  showCursor: true,
                  onTap: () {
                    setState(() {
                      _activeController = _priceController;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Price (₱)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _activeController == _priceController ? cs.primary : cs.onSurface.withOpacity(0.2),
                        width: _activeController == _priceController ? 2 : 1,
                      ),
                    ),
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a price.';
                    }
                    final price = double.tryParse(val);
                    if (price == null || price < 0) {
                      return 'Please enter a valid price.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Quantity Selector Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyController,
                        readOnly: true,
                        showCursor: true,
                        onTap: () {
                          setState(() {
                            _activeController = _qtyController;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _activeController == _qtyController ? cs.primary : cs.onSurface.withOpacity(0.2),
                              width: _activeController == _qtyController ? 2 : 1,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.production_quantity_limits),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a quantity.';
                          }
                          final qty = double.tryParse(val);
                          if (qty == null || qty <= 0) {
                            return 'Enter a valid quantity.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final q = double.tryParse(_qtyController.text) ?? 1.0;
                        if (q > 1) {
                          setState(() {
                            final newVal = q - 1.0;
                            _qtyController.text = newVal.toString();
                          });
                        } else if (q > 0.1) {
                          setState(() {
                            final newVal = double.parse((q - 0.1).toStringAsFixed(1));
                            _qtyController.text = newVal.toString();
                          });
                        }
                      },
                      icon: Icon(Icons.remove_circle_outline, color: cs.primary),
                    ),
                    IconButton(
                      onPressed: () {
                        final q = double.tryParse(_qtyController.text) ?? 1.0;
                        setState(() {
                          final newVal = double.parse((q + 1.0).toStringAsFixed(1));
                          _qtyController.text = newVal.toString();
                        });
                      },
                      icon: Icon(Icons.add_circle_outline, color: cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Virtual Keypad
                Text(
                  'Editing: ${_activeController == _priceController ? "Price" : "Quantity"}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                NumericKeypad(
                  controller: _activeController,
                  isDecimal: true,
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Add to Cart',
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
