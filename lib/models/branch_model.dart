class BranchModel {
  final String id;
  final String name;
  final String location;

  BranchModel({required this.id, required this.name, required this.location});

  Map<String, dynamic> toMap() => {'name': name, 'location': location};

  factory BranchModel.fromMap(String id, Map<String, dynamic> map) => BranchModel(
        id: id,
        name: map['name'] ?? '',
        location: map['location'] ?? '',
      );
}