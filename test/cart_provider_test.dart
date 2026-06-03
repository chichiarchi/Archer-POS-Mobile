import 'package:flutter_test/flutter_test.dart';
import 'package:archer_pos/core/providers/cart_provider.dart';

void main() {
  group('CartProvider Tests', () {
    test('Newly added items must always be on top', () {
      final provider = CartProvider();
      
      // Add first item
      provider.addItem({
        'id': 'item1',
        'name': 'Item 1',
        'price': 10.0,
        'wholesale_price': 8.0,
      }, 1, 'retail');
      
      expect(provider.items.length, 1);
      expect(provider.items[0].barcode, 'item1');
      
      // Add second item
      provider.addItem({
        'id': 'item2',
        'name': 'Item 2',
        'price': 20.0,
        'wholesale_price': 15.0,
      }, 2, 'retail');
      
      expect(provider.items.length, 2);
      // The newly added item must be on top (index 0)
      expect(provider.items[0].barcode, 'item2');
      expect(provider.items[1].barcode, 'item1');
      
      // Add first item again (duplicate scan) - should move it to the top
      provider.addItem({
        'id': 'item1',
        'name': 'Item 1',
        'price': 10.0,
        'wholesale_price': 8.0,
      }, 1, 'retail');
      
      expect(provider.items.length, 2);
      // Item 1 should now be at index 0 and its quantity updated to 2
      expect(provider.items[0].barcode, 'item1');
      expect(provider.items[0].quantity, 2);
      expect(provider.items[1].barcode, 'item2');
    });
  });
}
