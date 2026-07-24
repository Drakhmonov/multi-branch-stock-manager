import 'package:flutter_test/flutter_test.dart';
import 'package:branch_stock_app/models/order_model.dart';

void main() {
  group('OrderItem', () {
    test('round-trips without a fulfilledQuantity (not yet prepared)', () {
      final item = OrderItem(stockItemId: 's1', name: 'Buns', quantity: 10);

      final restored = OrderItem.fromMap(item.toMap());

      expect(restored.stockItemId, 's1');
      expect(restored.name, 'Buns');
      expect(restored.quantity, 10);
      expect(restored.fulfilledQuantity, isNull);
    });

    test('round-trips with a fulfilledQuantity that differs from requested', () {
      final item = OrderItem(
        stockItemId: 's1',
        name: 'Buns',
        quantity: 10,
        fulfilledQuantity: 7,
      );

      final restored = OrderItem.fromMap(item.toMap());

      expect(restored.quantity, 10);
      expect(restored.fulfilledQuantity, 7);
    });

    test('a kitchen-added item (not originally requested) has quantity 0', () {
      final item = OrderItem(
        stockItemId: 's2',
        name: 'Extra Sauce',
        quantity: 0,
        fulfilledQuantity: 3,
      );

      final restored = OrderItem.fromMap(item.toMap());

      expect(restored.quantity, 0);
      expect(restored.fulfilledQuantity, 3);
    });
  });

  group('OrderModel', () {
    OrderModel fullOrder() => OrderModel(
      id: 'o1',
      branchId: 'branch1',
      items: [OrderItem(stockItemId: 's1', name: 'Buns', quantity: 10)],
      status: OrderStatus.received,
      createdAt: DateTime(2026, 7, 24, 8, 0),
      placedByName: 'Branch Staff',
      note: 'Please deliver before lunch',
      preparingAt: DateTime(2026, 7, 24, 8, 30),
      preparedByName: 'Kitchen Staff',
      preparingNote: 'Substituted brand',
      deliveredAt: DateTime(2026, 7, 24, 9, 0),
      deliveredByName: 'Delivery Staff',
      deliveredNote: 'Left at back door',
      receivedAt: DateTime(2026, 7, 24, 9, 15),
      receivedByName: 'Branch Staff',
      receivedNote: 'All correct',
    );

    test('round-trips every field through toMap/fromMap', () {
      final restored = OrderModel.fromMap('o1', fullOrder().toMap());

      expect(restored.branchId, 'branch1');
      expect(restored.items, hasLength(1));
      expect(restored.status, OrderStatus.received);
      expect(restored.createdAt, DateTime(2026, 7, 24, 8, 0));
      expect(restored.placedByName, 'Branch Staff');
      expect(restored.note, 'Please deliver before lunch');
      expect(restored.preparingAt, DateTime(2026, 7, 24, 8, 30));
      expect(restored.preparedByName, 'Kitchen Staff');
      expect(restored.preparingNote, 'Substituted brand');
      expect(restored.deliveredAt, DateTime(2026, 7, 24, 9, 0));
      expect(restored.deliveredByName, 'Delivery Staff');
      expect(restored.deliveredNote, 'Left at back door');
      expect(restored.receivedAt, DateTime(2026, 7, 24, 9, 15));
      expect(restored.receivedByName, 'Branch Staff');
      expect(restored.receivedNote, 'All correct');
    });

    test(
      'a freshly placed order has no later-step fields set',
      () {
        final order = OrderModel(
          id: 'o2',
          branchId: 'branch1',
          items: [OrderItem(stockItemId: 's1', name: 'Buns', quantity: 5)],
          status: OrderStatus.requested,
          createdAt: DateTime(2026, 7, 24, 8, 0),
          placedByName: 'Branch Staff',
        );

        final restored = OrderModel.fromMap('o2', order.toMap());

        expect(restored.status, OrderStatus.requested);
        expect(restored.preparingAt, isNull);
        expect(restored.deliveredAt, isNull);
        expect(restored.receivedAt, isNull);
        expect(restored.note, isNull);
      },
    );

    test(
      'orders written before Phase 16 (no placedByName) fall back to Unknown',
      () {
        final restored = OrderModel.fromMap('o3', {
          'branchId': 'branch1',
          'items': [],
          'status': 'requested',
          'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        });

        expect(restored.placedByName, 'Unknown');
      },
    );

    test('unknown or missing status falls back to requested', () {
      final restored = OrderModel.fromMap('o4', {
        'branchId': 'branch1',
        'items': [],
        'status': 'not-a-real-status',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.status, OrderStatus.requested);
    });
  });
}
