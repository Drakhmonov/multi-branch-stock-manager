import 'package:flutter_test/flutter_test.dart';
import 'package:branch_stock_app/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('round-trips through toMap/fromMap', () {
      final user = UserModel(
        id: 'u1',
        name: 'Alice',
        role: UserRole.kitchenStaff,
        branchId: 'branch1',
      );

      final restored = UserModel.fromMap('u1', user.toMap());

      expect(restored.name, 'Alice');
      expect(restored.role, UserRole.kitchenStaff);
      expect(restored.branchId, 'branch1');
    });

    test('branchId stays null when not set (kitchen/delivery/manager)', () {
      final user = UserModel(id: 'u2', name: 'Bob', role: UserRole.manager);

      final restored = UserModel.fromMap('u2', user.toMap());

      expect(restored.branchId, isNull);
    });

    test('unknown or missing role falls back to branchStaff', () {
      final restored = UserModel.fromMap('u3', {
        'name': 'Charlie',
        'role': 'not-a-real-role',
      });

      expect(restored.role, UserRole.branchStaff);
    });
  });
}
