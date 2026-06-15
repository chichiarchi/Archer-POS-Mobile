/// Represents a customer in the EmmaSarmingStore system.
class Customer {
  final int? id;
  final String name;
  final String? address;
  final String? phone;

  const Customer({
    this.id,
    required this.name,
    this.address,
    this.phone,
  });

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Creates a [Customer] from a database row [map].
  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      address: map['address'] as String?,
      phone: map['phone'] as String?,
    );
  }

  /// Converts this [Customer] to a map suitable for database insertion.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'address': address,
      'phone': phone,
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
    );
  }

  @override
  String toString() =>
      'Customer(id: $id, name: $name, phone: $phone)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
