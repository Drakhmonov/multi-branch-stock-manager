import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:branch_stock_app/models/order_model.dart';
import 'package:branch_stock_app/widgets/order_status_timeline.dart';

void main() {
  Future<void> pumpTimeline(WidgetTester tester, OrderModel order) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OrderStatusTimeline(order: order)),
      ),
    );
  }

  testWidgets('a just-placed order only shows Requested as reached', (
    tester,
  ) async {
    final order = OrderModel(
      id: 'o1',
      branchId: 'branch1',
      items: const [],
      status: OrderStatus.requested,
      createdAt: DateTime(2026, 7, 24, 8, 0),
      placedByName: 'Branch Staff',
    );

    await pumpTimeline(tester, order);

    // All four step labels are always shown, reached or not.
    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);

    // Only the reached step gets a timestamp/actor line.
    expect(find.textContaining('by Branch Staff'), findsOneWidget);

    // Reached steps get a filled check; unreached steps stay outlined —
    // one check (Requested) and three outlined circles (the rest).
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
  });

  testWidgets('a fully received order shows all four steps with their notes', (
    tester,
  ) async {
    final order = OrderModel(
      id: 'o2',
      branchId: 'branch1',
      items: const [],
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

    await pumpTimeline(tester, order);

    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);

    expect(find.text('"Please deliver before lunch"'), findsOneWidget);
    expect(find.text('"Substituted brand"'), findsOneWidget);
    expect(find.text('"Left at back door"'), findsOneWidget);
    expect(find.text('"All correct"'), findsOneWidget);
  });
}
