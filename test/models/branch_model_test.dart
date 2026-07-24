import 'package:flutter_test/flutter_test.dart';
import 'package:branch_stock_app/models/branch_model.dart';

void main() {
  group('BranchModel', () {
    test('round-trips through toMap/fromMap', () {
      final branch = BranchModel(
        id: 'b1',
        name: 'City Centre',
        location: 'Manchester',
      );

      final restored = BranchModel.fromMap('b1', branch.toMap());

      expect(restored.id, 'b1');
      expect(restored.name, 'City Centre');
      expect(restored.location, 'Manchester');
    });

    test('fromMap defaults missing fields to empty strings', () {
      final branch = BranchModel.fromMap('b2', {});

      expect(branch.name, '');
      expect(branch.location, '');
    });
  });
}
