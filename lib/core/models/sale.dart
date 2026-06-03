/// Represents a completed sale transaction.
class Sale {
  final int? id;
  final double totalAmount;
  final double amountPaid;
  final double balanceDue;
  final int? customerId;
  final bool voided;
  final String timestamp;
  final String? customerName;

  const Sale({
    this.id,
    required this.totalAmount,
    required this.amountPaid,
    required this.balanceDue,
    this.customerId,
    this.voided = false,
    required this.timestamp,
    this.customerName,
  });

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  /// Amount of change to return to the customer.
  double get change => amountPaid - totalAmount;

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Creates a [Sale] from a database row [map].
  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as int?,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ??
          (map['total_amount'] as num?)?.toDouble() ??
          0.0,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ??
          (map['amount_paid'] as num?)?.toDouble() ??
          0.0,
      balanceDue: (map['balanceDue'] as num?)?.toDouble() ??
          (map['balance_due'] as num?)?.toDouble() ??
          0.0,
      customerId: map['customerId'] as int? ?? map['customer_id'] as int?,
      voided: (map['voided'] as int? ?? 0) == 1,
      timestamp: map['timestamp'] as String? ?? '',
      customerName:
          map['customerName'] as String? ?? map['customer_name'] as String?,
    );
  }

  /// Converts this [Sale] to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'balanceDue': balanceDue,
      'customerId': customerId,
      'voided': voided ? 1 : 0,
      'timestamp': timestamp,
      'customerName': customerName,
    };
  }

  Sale copyWith({
    int? id,
    double? totalAmount,
    double? amountPaid,
    double? balanceDue,
    int? customerId,
    bool? voided,
    String? timestamp,
    String? customerName,
  }) {
    return Sale(
      id: id ?? this.id,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      balanceDue: balanceDue ?? this.balanceDue,
      customerId: customerId ?? this.customerId,
      voided: voided ?? this.voided,
      timestamp: timestamp ?? this.timestamp,
      customerName: customerName ?? this.customerName,
    );
  }

  @override
  String toString() =>
      'Sale(id: $id, total: $totalAmount, paid: $amountPaid, voided: $voided, timestamp: $timestamp)';
}

// =============================================================================
// SaleItem
// =============================================================================

/// Represents a single line item within a [Sale].
class SaleItem {
  final int? id;
  final int saleId;
  final String productId;
  final String productName;
  final double quantity;
  final double price;

  const SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  /// Total for this line item.
  double get subtotal => price * quantity;

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Creates a [SaleItem] from a database row [map].
  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['saleId'] as int? ?? map['sale_id'] as int? ?? 0,
      productId:
          map['productId'] as String? ?? map['product_id'] as String? ?? '',
      productName: map['productName'] as String? ??
          map['product_name'] as String? ??
          '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this [SaleItem] to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'saleId': saleId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
    };
  }

  SaleItem copyWith({
    int? id,
    int? saleId,
    String? productId,
    String? productName,
    double? quantity,
    double? price,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }

  @override
  String toString() =>
      'SaleItem(saleId: $saleId, product: $productName, qty: $quantity, price: $price)';
}
