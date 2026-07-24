import 'package:flutter_test/flutter_test.dart';
import 'package:branch_stock_app/models/stock_movement_model.dart';

void main() {
  group('StockMovementModel', () {
    test('round-trips through toMap/fromMap for every movement type', () {
      for (final type in MovementType.values) {
        final movement = StockMovementModel(
          id: 'm1',
          type: type,
          itemId: 'item1',
          branchId: 'branch1',
          quantity: 5,
          costAtTime: 1.25,
          performedBy: 'user1',
          relatedOrderId: 'order1',
          timestamp: DateTime(2026, 7, 24, 10, 0),
          note: 'a note',
        );

        final restored = StockMovementModel.fromMap('m1', movement.toMap());

        expect(restored.type, type, reason: 'type $type should round-trip');
        expect(restored.itemId, 'item1');
        expect(restored.branchId, 'branch1');
        expect(restored.quantity, 5);
        expect(restored.costAtTime, 1.25);
        expect(restored.performedBy, 'user1');
        expect(restored.relatedOrderId, 'order1');
        expect(restored.timestamp, DateTime(2026, 7, 24, 10, 0));
        expect(restored.note, 'a note');
      }
    });

    test('unknown movement type falls back to adjustment', () {
      final restored = StockMovementModel.fromMap('m2', {
        'type': 'not-a-real-type',
        'itemId': 'item1',
        'quantity': 1,
        'costAtTime': 0,
        'performedBy': 'user1',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.type, MovementType.adjustment);
    });

    test('branchId and note stay null for central (non-branch) movements', () {
      final movement = StockMovementModel(
        id: 'm3',
        type: MovementType.restock,
        itemId: 'item1',
        branchId: null,
        quantity: 10,
        costAtTime: 2,
        performedBy: 'kitchen1',
        timestamp: DateTime(2026, 1, 1),
      );

      final restored = StockMovementModel.fromMap('m3', movement.toMap());

      expect(restored.branchId, isNull);
      expect(restored.note, isNull);
      expect(restored.relatedOrderId, isNull);
    });
  });
}
