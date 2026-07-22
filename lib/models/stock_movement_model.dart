enum MovementType {
  restock,
  orderDeducted,
  delivered,
  received,
  sold,
  wasted,
  adjustment,
}

class StockMovementModel {
  final String id;
  final MovementType type;
  final String itemId;
  final String? branchId;
  final double quantity;
  final double costAtTime;
  final String performedBy;
  final String? relatedOrderId;
  final DateTime timestamp;
  // Only meaningful for MovementType.adjustment: why a correction was made.
  final String? note;

  StockMovementModel({
    required this.id,
    required this.type,
    required this.itemId,
    this.branchId,
    required this.quantity,
    required this.costAtTime,
    required this.performedBy,
    this.relatedOrderId,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'itemId': itemId,
    'branchId': branchId,
    'quantity': quantity,
    'costAtTime': costAtTime,
    'performedBy': performedBy,
    'relatedOrderId': relatedOrderId,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
  };

  factory StockMovementModel.fromMap(String id, Map<String, dynamic> map) =>
      StockMovementModel(
        id: id,
        type: MovementType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => MovementType.adjustment,
        ),
        itemId: map['itemId'] ?? '',
        branchId: map['branchId'],
        quantity: (map['quantity'] ?? 0).toDouble(),
        costAtTime: (map['costAtTime'] ?? 0).toDouble(),
        performedBy: map['performedBy'] ?? '',
        relatedOrderId: map['relatedOrderId'],
        timestamp: DateTime.parse(map['timestamp']),
        note: map['note'],
      );
}
