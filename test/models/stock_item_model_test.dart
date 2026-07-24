import 'package:flutter_test/flutter_test.dart';
import 'package:branch_stock_app/models/stock_item_model.dart';

void main() {
  group('StockItemModel', () {
    test('round-trips through toMap/fromMap', () {
      final item = StockItemModel(
        id: 'i1',
        name: 'Chicken Dumplings',
        pieceUnit: 'pcs',
        packLabel: 'bag',
        piecesPerPack: 20,
        costPerPack: 10,
        costPerUnit: 0.5,
        currentQty: 100,
        reorderThreshold: 40,
        lastUpdated: DateTime(2026, 7, 24, 9, 30),
      );

      final restored = StockItemModel.fromMap('i1', item.toMap());

      expect(restored.name, 'Chicken Dumplings');
      expect(restored.pieceUnit, 'pcs');
      expect(restored.packLabel, 'bag');
      expect(restored.piecesPerPack, 20);
      expect(restored.costPerPack, 10);
      expect(restored.costPerUnit, 0.5);
      expect(restored.currentQty, 100);
      expect(restored.reorderThreshold, 40);
      expect(restored.lastUpdated, DateTime(2026, 7, 24, 9, 30));
    });

    test('falls back to legacy `unit` field when pieceUnit is missing', () {
      final item = StockItemModel.fromMap('i2', {
        'name': 'Oil',
        'unit': 'litre',
        'lastUpdated': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(item.pieceUnit, 'litre');
    });

    test('packLabel defaults to pieceUnit when not set (unpackaged item)', () {
      final item = StockItemModel.fromMap('i3', {
        'name': 'Salt',
        'pieceUnit': 'kg',
        'lastUpdated': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(item.packLabel, 'kg');
      expect(item.piecesPerPack, 1);
    });

    test('costPerPack falls back to legacy costPerUnit when missing', () {
      final item = StockItemModel.fromMap('i4', {
        'name': 'Legacy Item',
        'pieceUnit': 'pcs',
        'costPerUnit': 2.5,
        'lastUpdated': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(item.costPerPack, 2.5);
    });

    test('numeric fields default to 0 when missing', () {
      final item = StockItemModel.fromMap('i5', {
        'name': 'Bare Item',
        'lastUpdated': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(item.currentQty, 0);
      expect(item.reorderThreshold, 0);
      expect(item.costPerPack, 0);
      expect(item.costPerUnit, 0);
    });
  });
}
