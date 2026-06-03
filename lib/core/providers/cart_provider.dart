import 'dart:convert';
import 'package:flutter/foundation.dart';

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

/// Holds a bundle tier definition for tiered pricing logic.
class _BundleTier {
  final double quantity;
  final double pricePerPiece; // bundle.price / bundle.quantity
  final double wholesalePricePerPiece;

  const _BundleTier({
    required this.quantity,
    required this.pricePerPiece,
    required this.wholesalePricePerPiece,
  });
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String _pricingMode = 'retail';

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
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Extracts sorted bundle tiers from the product map for tiered pricing.
  List<_BundleTier> _extractBundles(Map<String, dynamic> product) {
    final rawBundles = product['bundles'];
    if (rawBundles == null || rawBundles is! List) return [];

    final tiers = <_BundleTier>[];
    for (final b in rawBundles) {
      if (b is Map<String, dynamic>) {
        final qty = (b['quantity'] as num?)?.toDouble() ?? 0;
        final bundlePrice = (b['price'] as num?)?.toDouble() ?? 0;
        final bundleWholesale = (b['wholesalePrice'] as num?)?.toDouble() ?? bundlePrice;
        if (qty > 0 && bundlePrice > 0) {
          tiers.add(_BundleTier(
            quantity: qty,
            pricePerPiece: bundlePrice / qty,
            wholesalePricePerPiece: bundleWholesale / qty,
          ));
        }
      }
    }

    // Sort descending by quantity so we pick the best (highest-qty) applicable tier.
    tiers.sort((a, b) => b.quantity.compareTo(a.quantity));
    return tiers;
  }

  /// Given a quantity and available bundle tiers, resolve the best unit price.
  /// Returns the base retail/wholesale price if no tier applies.
  double _resolvePriceForQty({
    required double qty,
    required List<_BundleTier> tiers,
    required double baseRetail,
    required double baseWholesale,
    required String mode,
  }) {
    for (final tier in tiers) {
      if (qty >= tier.quantity) {
        return mode == 'wholesale'
            ? tier.wholesalePricePerPiece
            : tier.pricePerPiece;
      }
    }
    return mode == 'wholesale' ? baseWholesale : baseRetail;
  }

  // ---------------------------------------------------------------------------
  // Public cart operations
  // ---------------------------------------------------------------------------

  /// Adds a product to the cart. Handles bundle/tiered pricing.
  ///
  /// [product] must include at minimum:
  ///   'barcode', 'name', 'price' (retail), 'wholesalePrice'
  /// and optionally 'bundles' (List of bundle maps).
  void addItem(
    Map<String, dynamic> product,
    double quantity,
    String mode, {
    List<dynamic>? bundles,
  }) {
    if (bundles != null) {
      product = Map<String, dynamic>.from(product)..['bundles'] = bundles;
    }
    final barcode = product['barcode'] as String? ?? '';
    final name = product['name'] as String? ?? 'Unknown';
    final baseRetail = (product['price'] as num?)?.toDouble() ?? 0.0;
    final baseWholesale =
        (product['wholesalePrice'] as num?)?.toDouble() ?? baseRetail;

    final tiers = _extractBundles(product);

    // Check if this barcode already exists in cart.
    final existingIndex =
        _items.indexWhere((item) => item.barcode == barcode);

    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      // Don't change manually discounted item's price when adding more qty.
      final newQty = existing.quantity + quantity;

      double newPrice = existing.price;
      if (!existing.manuallyDiscounted) {
        newPrice = _resolvePriceForQty(
          qty: newQty,
          tiers: tiers,
          baseRetail: baseRetail,
          baseWholesale: baseWholesale,
          mode: existing.pricingMode,
        );
      }

      _items[existingIndex] = existing.copyWith(
        quantity: newQty,
        price: newPrice,
      );
    } else {
      final unitPrice = _resolvePriceForQty(
        qty: quantity,
        tiers: tiers,
        baseRetail: baseRetail,
        baseWholesale: baseWholesale,
        mode: mode,
      );

      _items.add(CartItem(
        barcode: barcode,
        name: name,
        price: unitPrice,
        quantity: quantity,
        pricingMode: mode,
        manuallyDiscounted: false,
        retailPrice: baseRetail,
        wholesalePrice: baseWholesale,
      ));
    }

    notifyListeners();
  }

  /// Removes the item at [index] from the cart.
  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  /// Updates the quantity of the item at [index].
  /// Re-evaluates tiered pricing unless the item has a manual discount.
  void updateQuantity(int index, double qty) {
    if (index < 0 || index >= _items.length) return;
    if (qty <= 0) {
      removeItem(index);
      return;
    }

    final item = _items[index];
    _items[index] = item.copyWith(quantity: qty);
    notifyListeners();
  }

  /// Applies a manual discount by setting a new [newPrice] for the item at [index].
  /// Marks the item as manually discounted so global pricing changes won't override it.
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
    final restoredPrice = item.pricingMode == 'wholesale'
        ? item.wholesalePrice
        : item.retailPrice;
    _items[index] = item.copyWith(
      price: restoredPrice,
      manuallyDiscounted: false,
    );
    notifyListeners();
  }

  /// Toggles the pricing mode for a single item at [index] between retail/wholesale.
  /// Does not affect manually discounted items.
  void toggleItemPricing(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    if (item.manuallyDiscounted) return; // Respect manual discount

    final newMode =
        item.pricingMode == 'retail' ? 'wholesale' : 'retail';
    final newPrice =
        newMode == 'wholesale' ? item.wholesalePrice : item.retailPrice;

    _items[index] = item.copyWith(
      pricingMode: newMode,
      price: newPrice,
    );
    notifyListeners();
  }

  /// Toggles global pricing mode and updates all non-manually-discounted items.
  void toggleGlobalPricing() {
    _pricingMode = _pricingMode == 'retail' ? 'wholesale' : 'retail';

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.manuallyDiscounted) continue;

      final newPrice =
          _pricingMode == 'wholesale' ? item.wholesalePrice : item.retailPrice;
      _items[i] = item.copyWith(
        pricingMode: _pricingMode,
        price: newPrice,
      );
    }

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

      final newPrice =
          mode == 'wholesale' ? item.wholesalePrice : item.retailPrice;
      _items[i] = item.copyWith(
        pricingMode: mode,
        price: newPrice,
      );
    }

    notifyListeners();
  }

  /// Clears all items from the cart and resets pricing mode to retail.
  void clearCart() {
    _items.clear();
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
