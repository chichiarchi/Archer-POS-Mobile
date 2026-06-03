/// Represents a bundle / tiered-pricing rule for a product.
///
/// A bundle defines a quantity threshold at which a different unit price applies.
/// For example: buy 12 units at ₱5.00 each (instead of the retail ₱6.00).
class ProductBundle {
  final int? id;

  /// The barcode of the product this bundle belongs to.
  final String productId;

  /// Human-readable label for this bundle tier, e.g. "Dozen".
  final String bundleName;

  /// Minimum quantity required to trigger this bundle price.
  final double quantity;

  /// Retail price for the entire bundle (not per-unit).
  final double price;

  /// Wholesale price for the entire bundle (not per-unit).
  final double wholesalePrice;

  /// Cost / landed price for the entire bundle.
  final double cost;

  const ProductBundle({
    this.id,
    required this.productId,
    required this.bundleName,
    required this.quantity,
    required this.price,
    required this.wholesalePrice,
    required this.cost,
  });

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  /// Retail price per individual unit within this bundle.
  double get pricePerUnit => quantity > 0 ? price / quantity : 0.0;

  /// Wholesale price per individual unit within this bundle.
  double get wholesalePricePerUnit =>
      quantity > 0 ? wholesalePrice / quantity : 0.0;

  /// Cost per individual unit within this bundle.
  double get costPerUnit => quantity > 0 ? cost / quantity : 0.0;

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Creates a [ProductBundle] from a database row [map].
  factory ProductBundle.fromMap(Map<String, dynamic> map) {
    return ProductBundle(
      id: map['id'] as int?,
      productId: map['productId'] as String? ??
          map['product_id'] as String? ??
          '',
      bundleName: map['bundleName'] as String? ??
          map['bundle_name'] as String? ??
          '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      wholesalePrice: (map['wholesalePrice'] as num?)?.toDouble() ??
          (map['wholesale_price'] as num?)?.toDouble() ??
          0.0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this [ProductBundle] to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'productId': productId,
      'bundleName': bundleName,
      'quantity': quantity,
      'price': price,
      'wholesalePrice': wholesalePrice,
      'cost': cost,
    };
  }

  ProductBundle copyWith({
    int? id,
    String? productId,
    String? bundleName,
    double? quantity,
    double? price,
    double? wholesalePrice,
    double? cost,
  }) {
    return ProductBundle(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      bundleName: bundleName ?? this.bundleName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      cost: cost ?? this.cost,
    );
  }

  @override
  String toString() =>
      'ProductBundle(id: $id, product: $productId, name: $bundleName, qty: $quantity, price: $price)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductBundle &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
