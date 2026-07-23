enum OrderStatus { requested, preparing, delivered, received, cancelled }

class OrderItem {
  final String stockItemId;
  final String name;
  final double quantity;

  OrderItem({
    required this.stockItemId,
    required this.name,
    required this.quantity,
  });

  Map<String, dynamic> toMap() => {
    'stockItemId': stockItemId,
    'name': name,
    'quantity': quantity,
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
    stockItemId: map['stockItemId'] ?? '',
    name: map['name'] ?? '',
    quantity: (map['quantity'] ?? 0).toDouble(),
  );
}

class OrderModel {
  final String id;
  final String branchId;
  final List<OrderItem> items;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? preparingAt;
  final String? preparedByName;
  final DateTime? deliveredAt;
  final String? deliveredByName;
  final DateTime? receivedAt;
  final String? receivedByName;

  OrderModel({
    required this.id,
    required this.branchId,
    required this.items,
    required this.status,
    required this.createdAt,
    this.preparingAt,
    this.preparedByName,
    this.deliveredAt,
    this.deliveredByName,
    this.receivedAt,
    this.receivedByName,
  });

  Map<String, dynamic> toMap() => {
    'branchId': branchId,
    'items': items.map((i) => i.toMap()).toList(),
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    if (preparingAt != null) 'preparingAt': preparingAt!.toIso8601String(),
    if (preparedByName != null) 'preparedByName': preparedByName,
    if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
    if (deliveredByName != null) 'deliveredByName': deliveredByName,
    if (receivedAt != null) 'receivedAt': receivedAt!.toIso8601String(),
    if (receivedByName != null) 'receivedByName': receivedByName,
  };

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) => OrderModel(
    id: id,
    branchId: map['branchId'] ?? '',
    items: (map['items'] as List<dynamic>? ?? [])
        .map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
        .toList(),
    status: OrderStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => OrderStatus.requested,
    ),
    createdAt: DateTime.parse(map['createdAt']),
    preparingAt: map['preparingAt'] != null
        ? DateTime.parse(map['preparingAt'])
        : null,
    preparedByName: map['preparedByName'],
    deliveredAt: map['deliveredAt'] != null
        ? DateTime.parse(map['deliveredAt'])
        : null,
    deliveredByName: map['deliveredByName'],
    receivedAt: map['receivedAt'] != null
        ? DateTime.parse(map['receivedAt'])
        : null,
    receivedByName: map['receivedByName'],
  );
}
