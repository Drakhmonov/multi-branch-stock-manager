import 'package:flutter_test/flutter_test.dart';
import 'package:branch_stock_app/models/order_model.dart';
import 'package:branch_stock_app/utils/format.dart';

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

  group('orderItemsSummary', () {
    test('shows a plain quantity for an item not yet fulfilled', () {
      final summary = orderItemsSummary([
        OrderItem(stockItemId: 's1', name: 'Buns', quantity: 10),
      ]);

      expect(summary, 'Buns x10');
    });

    test('shows a plain quantity when fulfilled matches requested', () {
      final summary = orderItemsSummary([
        OrderItem(
          stockItemId: 's1',
          name: 'Buns',
          quantity: 10,
          fulfilledQuantity: 10,
        ),
      ]);

      expect(summary, 'Buns x10');
    });

    test('shows requested vs sent when kitchen fulfilled a different amount', () {
      final summary = orderItemsSummary([
        OrderItem(
          stockItemId: 's1',
          name: 'Buns',
          quantity: 10,
          fulfilledQuantity: 7,
        ),
      ]);

      expect(summary, 'Buns: requested 10, sent 7');
    });

    test('marks a kitchen-added item (quantity 0) as added', () {
      final summary = orderItemsSummary([
        OrderItem(
          stockItemId: 's2',
          name: 'Extra Sauce',
          quantity: 0,
          fulfilledQuantity: 3,
        ),
      ]);

      expect(summary, 'Extra Sauce x3 (added)');
    });

    test('joins multiple items with a comma', () {
      final summary = orderItemsSummary([
        OrderItem(stockItemId: 's1', name: 'Buns', quantity: 10),
        OrderItem(
          stockItemId: 's2',
          name: 'Dumplings',
          quantity: 5,
          fulfilledQuantity: 4,
        ),
      ]);

      expect(summary, 'Buns x10, Dumplings: requested 5, sent 4');
    });
  });
}
