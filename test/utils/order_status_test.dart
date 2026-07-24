import 'package:flutter_test/flutter_test.dart';
import 'package:branch_stock_app/models/order_model.dart';
import 'package:branch_stock_app/utils/order_status.dart';

void main() {
  group('orderStatusLabel', () {
    test('has a human-readable label for every status', () {
      expect(orderStatusLabel(OrderStatus.requested), 'Requested');
      expect(orderStatusLabel(OrderStatus.preparing), 'Preparing');
      expect(orderStatusLabel(OrderStatus.prepared), 'Prepared');
      expect(orderStatusLabel(OrderStatus.delivered), 'Delivered');
      expect(orderStatusLabel(OrderStatus.received), 'Received');
      expect(orderStatusLabel(OrderStatus.cancelled), 'Cancelled');
    });
  });
}
