import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:branch_stock_app/widgets/stream_error_view.dart';

void main() {
  testWidgets('shows a plain-language message and the underlying error', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreamErrorView(error: 'permission-denied'),
        ),
      ),
    );

    expect(find.text('Couldn\'t load this data.'), findsOneWidget);
    expect(find.text('permission-denied'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('renders a null error without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StreamErrorView(error: null)),
      ),
    );

    expect(find.text('Couldn\'t load this data.'), findsOneWidget);
  });
}
