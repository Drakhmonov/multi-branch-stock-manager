import 'package:flutter_test/flutter_test.dart';
import 'package:branch_stock_app/models/order_model.dart';
import 'package:branch_stock_app/models/stock_item_model.dart';
import 'package:branch_stock_app/utils/format.dart';

StockItemModel _unpackaged({String id = 's1', String pieceUnit = 'pcs'}) =>
    StockItemModel(
      id: id,
      name: 'Buns',
      pieceUnit: pieceUnit,
      packLabel: pieceUnit,
      piecesPerPack: 1,
      costPerPack: 1,
      costPerUnit: 1,
      currentQty: 100,
      reorderThreshold: 10,
      lastUpdated: DateTime(2026, 1, 1),
    );

StockItemModel _packaged({
  String id = 's2',
  double piecesPerPack = 20,
  String packLabel = 'bag',
}) => StockItemModel(
  id: id,
  name: 'Dumplings',
  pieceUnit: 'pcs',
  packLabel: packLabel,
  piecesPerPack: piecesPerPack,
  costPerPack: 10,
  costPerUnit: 0.5,
  currentQty: 200,
  reorderThreshold: 40,
  lastUpdated: DateTime(2026, 1, 1),
);

void main() {
  group('formatTimestamp', () {
    test('pads single-digit month, day, hour, and minute with zeros', () {
      final result = formatTimestamp(DateTime(2026, 1, 5, 9, 3));

      expect(result, '2026-01-05 09:03');
    });

    test('does not pad already double-digit values', () {
      final result = formatTimestamp(DateTime(2026, 12, 24, 23, 59));

      expect(result, '2026-12-24 23:59');
    });
  });

  group('formatQty', () {
    test('drops the decimal for whole numbers', () {
      expect(formatQty(10), '10');
      expect(formatQty(0), '0');
    });

    test('keeps the decimal for fractional quantities', () {
      expect(formatQty(2.5), '2.5');
    });
  });

  group('formatItemQty', () {
    test('falls back to a bare piece count when the item is unknown', () {
      expect(formatItemQty(10, null), '10');
    });

    test('shows the piece unit when the catalog item is unpackaged', () {
      expect(formatItemQty(10, _unpackaged()), '10 pcs');
    });

    test('converts to whole packs for a packaged item', () {
      // 40 pieces at 20 pieces/bag = 2 bags.
      expect(formatItemQty(40, _packaged()), '2 bags (40 pcs)');
    });

    test('uses singular pack label for exactly one pack', () {
      expect(formatItemQty(20, _packaged()), '1 bag (20 pcs)');
    });

    test('shows a fractional pack count to one decimal place', () {
      // 30 pieces at 20 pieces/bag = 1.5 bags -- not a whole pack.
      expect(formatItemQty(30, _packaged()), '1.5 bags (30 pcs)');
    });
  });

  group('orderItemsSummary', () {
    test('shows a plain quantity for an item not in the catalog', () {
      final summary = orderItemsSummary([
        OrderItem(stockItemId: 's1', name: 'Buns', quantity: 10),
      ], {});

      expect(summary, 'Buns x10');
    });

    test('shows the piece unit for an unpackaged catalog item', () {
      final summary = orderItemsSummary([
        OrderItem(stockItemId: 's1', name: 'Buns', quantity: 10),
      ], {'s1': _unpackaged()});

      expect(summary, 'Buns x10 pcs');
    });

    test('shows packs (with pieces) for a packaged item, not raw pieces', () {
      final summary = orderItemsSummary([
        OrderItem(stockItemId: 's2', name: 'Dumplings', quantity: 40),
      ], {'s2': _packaged()});

      expect(summary, 'Dumplings x2 bags (40 pcs)');
    });

    test(
      'shows requested vs sent in packs when kitchen fulfilled a different amount',
      () {
        final summary = orderItemsSummary([
          OrderItem(
            stockItemId: 's2',
            name: 'Dumplings',
            quantity: 40,
            fulfilledQuantity: 20,
          ),
        ], {'s2': _packaged()});

        expect(
          summary,
          'Dumplings: requested 2 bags (40 pcs), sent 1 bag (20 pcs)',
        );
      },
    );

    test('marks a kitchen-added packaged item (quantity 0) as added', () {
      final summary = orderItemsSummary([
        OrderItem(
          stockItemId: 's2',
          name: 'Dumplings',
          quantity: 0,
          fulfilledQuantity: 20,
        ),
      ], {'s2': _packaged()});

      expect(summary, 'Dumplings x1 bag (20 pcs) (added)');
    });

    test('joins multiple items with a comma', () {
      final summary = orderItemsSummary([
        OrderItem(stockItemId: 's1', name: 'Buns', quantity: 10),
        OrderItem(
          stockItemId: 's2',
          name: 'Dumplings',
          quantity: 40,
          fulfilledQuantity: 20,
        ),
      ], {'s1': _unpackaged(), 's2': _packaged()});

      expect(
        summary,
        'Buns x10 pcs, Dumplings: requested 2 bags (40 pcs), sent 1 bag (20 pcs)',
      );
    });
  });
}
