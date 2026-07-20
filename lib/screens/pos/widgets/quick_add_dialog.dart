import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/formatters.dart';
import 'numeric_keypad.dart';

class QuickAddPreset {
  final String name;
  final double price;

  QuickAddPreset({required this.name, required this.price});

  Map<String, dynamic> toJson() => {'name': name, 'price': price};

  factory QuickAddPreset.fromJson(Map<String, dynamic> json) {
    return QuickAddPreset(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class QuickAddDialog extends StatefulWidget {
  const QuickAddDialog({super.key});

  @override
  State<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<QuickAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');

  late TextEditingController _activeController;

  static final List<QuickAddPreset> _defaultPresets = [
    QuickAddPreset(name: 'Ice Bag', price: 10.0),
    QuickAddPreset(name: 'Plastic Bag', price: 2.0),
    QuickAddPreset(name: 'Service Fee', price: 50.0),
    QuickAddPreset(name: 'Delivery Fee', price: 100.0),
    QuickAddPreset(name: 'Extra Box', price: 15.0),
  ];

  List<QuickAddPreset> _presets = [];
  bool _isLoadingPresets = true;

  @override
  void initState() {
    super.initState();
    _activeController = _priceController;
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawStr = prefs.getString('quick_add_presets_v1');
      if (rawStr != null && rawStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawStr);
        final loaded = decoded.map((e) => QuickAddPreset.fromJson(e as Map<String, dynamic>)).toList();
        if (mounted) {
          setState(() {
            _presets = loaded;
            _isLoadingPresets = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _presets = List.from(_defaultPresets);
            _isLoadingPresets = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _presets = List.from(_defaultPresets);
          _isLoadingPresets = false;
        });
      }
    }
  }

  Future<void> _savePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_presets.map((p) => p.toJson()).toList());
      await prefs.setString('quick_add_presets_v1', encoded);
    } catch (_) {}
  }

  void _addCurrentAsPreset() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    if (name.isEmpty || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name and price first.')),
      );
      return;
    }

    setState(() {
      _presets.removeWhere((p) => p.name.toLowerCase() == name.toLowerCase());
      _presets.add(QuickAddPreset(name: name, price: price));
    });
    _savePresets();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "$name" to Quick Add presets!')),
    );
  }

  void _removePreset(QuickAddPreset preset) {
    setState(() {
      _presets.removeWhere((p) => p.name == preset.name && p.price == preset.price);
    });
    _savePresets();
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
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isTablet = mediaQuery.size.shortestSide >= 600;
    final useSideBySide = isTablet && isLandscape;
    final maxHeight = mediaQuery.size.height * 0.85;

    Widget buildHeader() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Quick Add Custom Item',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: cs.onSurface.withValues(alpha: 0.6)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    Widget buildInputFields() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  color: _activeController == _priceController ? cs.primary : cs.onSurface.withValues(alpha: 0.2),
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

          // Quantity Field (Manual Type + 1-500 Dropdown Suffix)
          TextFormField(
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
                  color: _activeController == _qtyController ? cs.primary : cs.onSurface.withValues(alpha: 0.2),
                  width: _activeController == _qtyController ? 2 : 1,
                ),
              ),
              prefixIcon: const Icon(Icons.production_quantity_limits),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    icon: const Icon(Icons.arrow_drop_down),
                    isDense: true,
                    menuMaxHeight: 300,
                    items: List.generate(
                      500,
                      (i) => DropdownMenuItem<int>(
                        value: i + 1,
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _qtyController.text = val.toString();
                          _activeController = _qtyController;
                        });
                      }
                    },
                  ),
                ),
              ),
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
        ],
      );
    }

    Widget buildNumpadSection() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Editing: ${_activeController == _priceController ? "Price" : "Quantity"}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          NumericKeypad(
            controller: _activeController,
            isDecimal: _activeController == _priceController,
          ),
        ],
      );
    }

    Widget buildPresetsSection() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'COMMON ITEMS PRESETS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _addCurrentAsPreset,
                icon: const Icon(Icons.bookmark_add_outlined, size: 14),
                label: Text(
                  'Save Preferences',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _isLoadingPresets
              ? const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _presets)
                      InputChip(
                        label: Text('${p.name} (${formatCurrency(p.price)})'),
                        onPressed: () {
                          setState(() {
                            _nameController.text = p.name;
                            _priceController.text = p.price.toStringAsFixed(2);
                          });
                        },
                        onDeleted: () => _removePreset(p),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        backgroundColor: cs.primary.withValues(alpha: 0.08),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                        side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
                      ),
                  ],
                ),
        ],
      );
    }

    Widget buildActionButtons() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: useSideBySide ? 750 : 420,
          maxHeight: maxHeight,
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildHeader(),
                const Divider(height: 20),
                if (useSideBySide) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: buildInputFields(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: buildNumpadSection(),
                      ),
                    ],
                  ),
                ] else ...[
                  buildInputFields(),
                  const SizedBox(height: 16),
                  buildNumpadSection(),
                ],
                const SizedBox(height: 16),

                // Primary Action Buttons (Above Presets)
                buildActionButtons(),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Common Presets Section occupying bottom area
                buildPresetsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
