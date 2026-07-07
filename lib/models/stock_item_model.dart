class StockItemModel {
  final String id;
  final String name;
  final String unit;
  final double costPerUnit;
  final double currentQty;
  final double reorderThreshold;
  final DateTime lastUpdated;

  StockItemModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.costPerUnit,
    required this.currentQty,
    required this.reorderThreshold,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'unit': unit,
        'costPerUnit': costPerUnit,
        'currentQty': currentQty,
        'reorderThreshold': reorderThreshold,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory StockItemModel.fromMap(String id, Map<String, dynamic> map) =>
      StockItemModel(
        id: id,
        name: map['name'] ?? '',
        unit: map['unit'] ?? '',
        costPerUnit: (map['costPerUnit'] ?? 0).toDouble(),
        currentQty: (map['currentQty'] ?? 0).toDouble(),
        reorderThreshold: (map['reorderThreshold'] ?? 0).toDouble(),
        lastUpdated: DateTime.parse(map['lastUpdated']),
      );
}