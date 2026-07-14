enum OrderStatus { requested, preparing, delivered, received, cancelled }

class OrderItem {
  final String stockItemId;
  final String name;
  final double quantity;

  OrderItem({required this.stockItemId, required this.name, required this.quantity});

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

  OrderModel({
    required this.id,
    required this.branchId,
    required this.items,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'branchId': branchId,
        'items': items.map((i) => i.toMap()).toList(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
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
      );
}