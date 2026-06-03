import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickAddDialog extends StatefulWidget {
  const QuickAddDialog({super.key});

  @override
  State<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<QuickAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  double _quantity = 1.0;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'name': _nameController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'quantity': _quantity,
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price (₱)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 16),

              // Quantity Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quantity',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() {
                              _quantity -= 1.0;
                            });
                          } else if (_quantity > 0.1) {
                            setState(() {
                              _quantity = double.parse((_quantity - 0.1).toStringAsFixed(1));
                            });
                          }
                        },
                        icon: Icon(Icons.remove_circle_outline, color: cs.primary),
                      ),
                      Text(
                        _quantity.toString(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: cs.onSurface,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _quantity = double.parse((_quantity + 1.0).toStringAsFixed(1));
                          });
                        },
                        icon: Icon(Icons.add_circle_outline, color: cs.primary),
                      ),
                    ],
                  )
                ],
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
              )
            ],
          ),
        ),
      ),
    );
  }
}
