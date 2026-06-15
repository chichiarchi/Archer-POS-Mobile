/// Represents a product in the EmmaSarmingStore inventory.
class Product {
  /// Barcode — also used as the unique identifier.
  final String id;
  final String name;

  /// Default retail price per unit.
  final double price;

  /// Wholesale price per unit.
  final double wholesalePrice;

  /// Cost / landed price per unit (for profit calculation).
  final double cost;

  /// Optional product category.
  final String? category;

  /// Whether this product has any bundle/tiered pricing rules.
  final bool hasBundle;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.wholesalePrice,
    required this.cost,
    this.category,
    this.hasBundle = false,
  });

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Creates a [Product] from a database row [map].
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['barcode'] as String? ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      wholesalePrice: (map['wholesalePrice'] as num?)?.toDouble() ??
          (map['wholesale_price'] as num?)?.toDouble() ??
          0.0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String?,
      hasBundle: (map['hasBundle'] as int? ?? map['has_bundle'] as int? ?? 0) == 1,
    );
  }

  /// Converts this [Product] to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'barcode': id,
      'name': name,
      'price': price,
      'wholesalePrice': wholesalePrice,
      'cost': cost,
      'category': category,
      'hasBundle': hasBundle ? 1 : 0,
    };
  }

  @override
  String toString() =>
      'Product(id: $id, name: $name, price: $price, category: $category)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Product copyWith({
    String? id,
    String? name,
    double? price,
    double? wholesalePrice,
    double? cost,
    String? category,
    bool? hasBundle,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      cost: cost ?? this.cost,
      category: category ?? this.category,
      hasBundle: hasBundle ?? this.hasBundle,
    );
  }
}
