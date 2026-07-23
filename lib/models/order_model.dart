enum OrderStatus { requested, preparing, delivered, received, cancelled }

class OrderItem {
  final String stockItemId;
  final String name;
  final double quantity;
  final double? fulfilledQuantity;

  OrderItem({
    required this.stockItemId,
    required this.name,
    required this.quantity,
    this.fulfilledQuantity,
  });

  Map<String, dynamic> toMap() => {
    'stockItemId': stockItemId,
    'name': name,
    'quantity': quantity,
    if (fulfilledQuantity != null) 'fulfilledQuantity': fulfilledQuantity,
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
    stockItemId: map['stockItemId'] ?? '',
    name: map['name'] ?? '',
    quantity: (map['quantity'] ?? 0).toDouble(),
    fulfilledQuantity: map['fulfilledQuantity'] != null
        ? (map['fulfilledQuantity'] as num).toDouble()
        : null,
  );
}

class OrderModel {
  final String id;
  final String branchId;
  final List<OrderItem> items;
  final OrderStatus status;
  final DateTime createdAt;
  final String placedByName;
  final String? note;
  final DateTime? preparingAt;
  final String? preparedByName;
  final String? preparingNote;
  final DateTime? deliveredAt;
  final String? deliveredByName;
  final String? deliveredNote;
  final DateTime? receivedAt;
  final String? receivedByName;
  final String? receivedNote;

  OrderModel({
    required this.id,
    required this.branchId,
    required this.items,
    required this.status,
    required this.createdAt,
    this.placedByName = 'Unknown',
    this.note,
    this.preparingAt,
    this.preparedByName,
    this.preparingNote,
    this.deliveredAt,
    this.deliveredByName,
    this.deliveredNote,
    this.receivedAt,
    this.receivedByName,
    this.receivedNote,
  });

  Map<String, dynamic> toMap() => {
    'branchId': branchId,
    'items': items.map((i) => i.toMap()).toList(),
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'placedByName': placedByName,
    if (note != null) 'note': note,
    if (preparingAt != null) 'preparingAt': preparingAt!.toIso8601String(),
    if (preparedByName != null) 'preparedByName': preparedByName,
    if (preparingNote != null) 'preparingNote': preparingNote,
    if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
    if (deliveredByName != null) 'deliveredByName': deliveredByName,
    if (deliveredNote != null) 'deliveredNote': deliveredNote,
    if (receivedAt != null) 'receivedAt': receivedAt!.toIso8601String(),
    if (receivedByName != null) 'receivedByName': receivedByName,
    if (receivedNote != null) 'receivedNote': receivedNote,
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
    placedByName: map['placedByName'] ?? 'Unknown',
    note: map['note'],
    preparingAt: map['preparingAt'] != null
        ? DateTime.parse(map['preparingAt'])
        : null,
    preparedByName: map['preparedByName'],
    preparingNote: map['preparingNote'],
    deliveredAt: map['deliveredAt'] != null
        ? DateTime.parse(map['deliveredAt'])
        : null,
    deliveredByName: map['deliveredByName'],
    deliveredNote: map['deliveredNote'],
    receivedAt: map['receivedAt'] != null
        ? DateTime.parse(map['receivedAt'])
        : null,
    receivedByName: map['receivedByName'],
    receivedNote: map['receivedNote'],
  );
}
