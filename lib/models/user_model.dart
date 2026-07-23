enum UserRole { branchStaff, kitchenStaff, delivery, manager }

class UserModel {
  final String id;
  final String name;
  final UserRole role;
  final String? branchId;

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.branchId,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'role': role.name,
    'branchId': branchId,
  };

  factory UserModel.fromMap(String id, Map<String, dynamic> map) => UserModel(
    id: id,
    name: map['name'] ?? '',
    role: UserRole.values.firstWhere(
      (r) => r.name == map['role'],
      orElse: () => UserRole.branchStaff,
    ),
    branchId: map['branchId'],
  );
}
