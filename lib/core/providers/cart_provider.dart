import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// Represents a single item in the shopping cart.
class CartItem {
  String barcode;
  String name;
  double price;
  double quantity;
  String pricingMode; // 'retail' or 'wholesale'
  bool manuallyDiscounted;
  double retailPrice;
  double wholesalePrice;

  CartItem({
    required this.barcode,
    required this.name,
    required this.price,
    required this.quantity,
    this.pricingMode = 'retail',
    this.manuallyDiscounted = false,
    required this.retailPrice,
    required this.wholesalePrice,
  });

  double get subtotal => price * quantity;

  CartItem copyWith({
    String? barcode,
    String? name,
    double? price,
    double? quantity,
    String? pricingMode,
    bool? manuallyDiscounted,
    double? retailPrice,
    double? wholesalePrice,
  }) {
    return CartItem(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      pricingMode: pricingMode ?? this.pricingMode,
      manuallyDiscounted: manuallyDiscounted ?? this.manuallyDiscounted,
      retailPrice: retailPrice ?? this.retailPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
    );
  }

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'price': price,
        'quantity': quantity,
        'pricingMode': pricingMode,
        'manuallyDiscounted': manuallyDiscounted,
        'retailPrice': retailPrice,
        'wholesalePrice': wholesalePrice,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        barcode: json['barcode'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
        pricingMode: json['pricingMode'] as String? ?? 'retail',
        manuallyDiscounted: json['manuallyDiscounted'] as bool? ?? false,
        retailPrice: (json['retailPrice'] as num).toDouble(),
        wholesalePrice: (json['wholesalePrice'] as num).toDouble(),
      );
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String _pricingMode = 'retail';
  
  // Store bundle definitions for each product in the cart
  final Map<String, List<Map<String, dynamic>>> _productBundles = {};

  /// All items currently in the cart.
  List<CartItem> get items => List.unmodifiable(_items);

  /// The global pricing mode: 'retail' or 'wholesale'.
  String get pricingMode => _pricingMode;

  /// Total value of the cart (sum of each item's price * quantity).
  double get total =>
      _items.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  /// Number of distinct line-items in the cart.
  int get itemCount => _items.length;

  /// Total quantity across all items.
  double get totalQuantity =>
      _items.fold(0.0, (sum, item) => sum + item.quantity);

  // ---------------------------------------------------------------------------
  // Internal pricing recalculation (Python equivalent)
  // ---------------------------------------------------------------------------

  void _recalculatePrices() {
    // Group items by barcode
    final grouped = <String, List<CartItem>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.barcode, () => []).add(item);
    }

    for (final entry in grouped.entries) {
      final barcode = entry.key;
      final prodItems = entry.value;

      // Sum up total quantity of this barcode in the cart
      final totalQty = prodItems.fold<double>(0.0, (sum, item) => sum + item.quantity);

      // Get bundles for this barcode
      final bundles = _productBundles[barcode] ?? [];

      for (final item in prodItems) {
        if (item.manuallyDiscounted) continue;

        final basePrice = item.pricingMode == 'wholesale' && item.wholesalePrice > 0
            ? item.wholesalePrice
            : item.retailPrice;

        if (bundles.isEmpty) {
          item.price = basePrice;
          continue;
        }

        // Find all unlocked per-piece rates based on the total quantity
        final unlockedRates = <double>[];

        for (final b in bundles) {
          final qty = (b['quantity'] as num?)?.toDouble() ?? 0.0;
          if (qty > 0 && qty <= totalQty) {
            final bPrice = item.pricingMode == 'wholesale'
                ? ((b['wholesale_price'] as num?)?.toDouble() ?? 0.0)
                : ((b['price'] as num?)?.toDouble() ?? 0.0);
            
            final finalBPrice = bPrice > 0 ? bPrice : ((b['price'] as num?)?.toDouble() ?? 0.0);
            unlockedRates.add(finalBPrice / qty);
          }
        }

        if (unlockedRates.isNotEmpty) {
          // Apply the best unlocked rate (cheapest per-piece price)
          final bestRate = unlockedRates.reduce((a, b) => a < b ? a : b);
          item.price = bestRate;
        } else {
          item.price = basePrice;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Public cart operations
  // ---------------------------------------------------------------------------

  /// Adds a product to the cart. Handles bundle/tiered pricing.
  void addItem(
    Map<String, dynamic> product,
    double quantity,
    String mode, {
    List<dynamic>? bundles,
  }) {
    final barcode = product['barcode'] as String? ?? product['id'] as String? ?? '';
    final name = product['name'] as String? ?? 'Unknown';
    final baseRetail = (product['price'] as num?)?.toDouble() ?? 0.0;
    final baseWholesale =
        (product['wholesale_price'] as num? ?? product['wholesalePrice'] as num?)?.toDouble() ?? baseRetail;

    if (bundles != null) {
      _productBundles[barcode] = List<Map<String, dynamic>>.from(bundles);
    }

    // Check if this barcode already exists in cart with matching mode.
    final existingIndex =
        _items.indexWhere((item) => item.barcode == barcode && item.pricingMode == mode);

    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      final newQty = existing.quantity + quantity;
      _items[existingIndex] = existing.copyWith(quantity: newQty);
    } else {
      _items.add(CartItem(
        barcode: barcode,
        name: name,
        price: mode == 'wholesale' && baseWholesale > 0 ? baseWholesale : baseRetail,
        quantity: quantity,
        pricingMode: mode,
        manuallyDiscounted: false,
        retailPrice: baseRetail,
        wholesalePrice: baseWholesale,
      ));
    }

    _recalculatePrices();
    notifyListeners();
  }

  /// Removes the item at [index] from the cart.
  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    _items.removeAt(index);
    
    // If no more items with this barcode exist in cart, clear the bundle configuration
    if (_items.where((i) => i.barcode == item.barcode).isEmpty) {
      _productBundles.remove(item.barcode);
    }
    
    _recalculatePrices();
    notifyListeners();
  }

  /// Updates the quantity of the item at [index].
  void updateQuantity(int index, double qty) {
    if (index < 0 || index >= _items.length) return;
    if (qty <= 0) {
      removeItem(index);
      return;
    }

    final item = _items[index];
    _items[index] = item.copyWith(quantity: qty);
    _recalculatePrices();
    notifyListeners();
  }

  /// Applies a manual discount by setting a new [newPrice] for the item at [index].
  void applyDiscount(int index, double newPrice) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    _items[index] = item.copyWith(
      price: newPrice,
      manuallyDiscounted: true,
    );
    notifyListeners();
  }

  /// Removes a manual discount from the item at [index] and restores the mode price.
  void removeDiscount(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    _items[index] = item.copyWith(
      manuallyDiscounted: false,
    );
    _recalculatePrices();
    notifyListeners();
  }

  /// Toggles the pricing mode for a single item at [index] between retail/wholesale.
  void toggleItemPricing(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    if (item.manuallyDiscounted) return; // Respect manual discount

    final newMode =
        item.pricingMode == 'retail' ? 'wholesale' : 'retail';

    _items[index] = item.copyWith(
      pricingMode: newMode,
    );
    _recalculatePrices();
    notifyListeners();
  }

  /// Toggles global pricing mode and updates all non-manually-discounted items.
  void toggleGlobalPricing() {
    _pricingMode = _pricingMode == 'retail' ? 'wholesale' : 'retail';

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.manuallyDiscounted) continue;

      _items[i] = item.copyWith(
        pricingMode: _pricingMode,
      );
    }

    _recalculatePrices();
    notifyListeners();
  }

  /// Sets the global pricing mode explicitly without toggle.
  void setPricingMode(String mode) {
    if (mode != 'retail' && mode != 'wholesale') return;
    if (_pricingMode == mode) return;
    _pricingMode = mode;

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.manuallyDiscounted) continue;

      _items[i] = item.copyWith(
        pricingMode: mode,
      );
    }

    _recalculatePrices();
    notifyListeners();
  }

  /// Clears all items from the cart and resets pricing mode to retail.
  void clearCart() {
    _items.clear();
    _productBundles.clear();
    _pricingMode = 'retail';
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Parking / Recalling
  // ---------------------------------------------------------------------------

  /// Serialises the cart to a JSON string for parking (saving to DB).
  String toJson() {
    return jsonEncode({
      'pricingMode': _pricingMode,
      'items': _items.map((e) => e.toJson()).toList(),
    });
  }

  /// Restores the cart from a previously parked JSON string.
  void fromJson(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _pricingMode = data['pricingMode'] as String? ?? 'retail';
      _items.clear();
      final rawItems = data['items'] as List<dynamic>? ?? [];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          _items.add(CartItem.fromJson(raw));
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('CartProvider.fromJson error: $e');
    }
  }

  /// Returns a deep copy of the cart items as a list of maps for receipt/sale saving.
  List<Map<String, dynamic>> toSaleItems() {
    return _items
        .map((item) => {
              'barcode': item.barcode,
              'name': item.name,
              'quantity': item.quantity,
              'price': item.price,
              'subtotal': item.subtotal,
              'pricingMode': item.pricingMode,
            })
        .toList();
  }
}
