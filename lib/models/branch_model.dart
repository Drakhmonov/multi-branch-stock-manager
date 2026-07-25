class BranchModel {
  final String id;
  final String name;
  final String location;
  // Archived branches are hidden from active use (new sign-ups, etc.) but
  // never deleted — their historical orders/stock/reports stay intact and
  // still resolve to a real name, not a raw id.
  final bool active;

  BranchModel({
    required this.id,
    required this.name,
    required this.location,
    this.active = true,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'location': location,
    'active': active,
  };

  factory BranchModel.fromMap(String id, Map<String, dynamic> map) =>
      BranchModel(
        id: id,
        name: map['name'] ?? '',
        location: map['location'] ?? '',
        active: map['active'] ?? true,
      );
}
