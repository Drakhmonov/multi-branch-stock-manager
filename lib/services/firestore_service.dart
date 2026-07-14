import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stock_item_model.dart';
import '../models/order_model.dart';
import '../models/stock_movement_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ---------- STOCK ITEMS (central) ----------

  Stream<List<StockItemModel>> streamStockItems() {
    return _db.collection('stockItems').snapshots().map((snap) => snap.docs
        .map((doc) => StockItemModel.fromMap(doc.id, doc.data()))
        .toList());
  }

  Future<void> addStockItem(StockItemModel item) async {
    await _db.collection('stockItems').doc(item.id).set(item.toMap());
  }

  /// Central kitchen restocks an item: increases central quantity, logs a movement.
  Future<void> restock({
    required String itemId,
    required double quantity,
    required double cost,
    required String performedBy,
  }) async {
    final itemRef = _db.collection('stockItems').doc(itemId);
    final movementRef = _db.collection('stockMovements').doc();

    await _db.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      final currentQty = (itemSnap.data()?['currentQty'] ?? 0).toDouble();

      tx.update(itemRef, {
        'currentQty': currentQty + quantity,
        'costPerUnit': cost,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      tx.set(movementRef, StockMovementModel(
        id: movementRef.id,
        type: MovementType.restock,
        itemId: itemId,
        branchId: null,
        quantity: quantity,
        costAtTime: cost,
        performedBy: performedBy,
        timestamp: DateTime.now(),
      ).toMap());
    });
  }

  // ---------- ORDERS ----------

  Future<void> placeOrder({
    required String branchId,
    required List<OrderItem> items,
  }) async {
    final orderRef = _db.collection('orders').doc();
    await orderRef.set(OrderModel(
      id: orderRef.id,
      branchId: branchId,
      items: items,
      status: OrderStatus.requested,
      createdAt: DateTime.now(),
    ).toMap());
  }

  Stream<List<OrderModel>> streamOrders({String? branchId}) {
    Query query = _db.collection('orders').orderBy('createdAt', descending: true);
    if (branchId != null) {
      query = query.where('branchId', isEqualTo: branchId);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  /// Kitchen prepares an order: deducts central stock for each item, marks it preparing.
  Future<void> prepareOrder(OrderModel order, String performedBy) async {
    await _db.runTransaction((tx) async {
      for (final item in order.items) {
        final itemRef = _db.collection('stockItems').doc(item.stockItemId);
        final itemSnap = await tx.get(itemRef);
        final data = itemSnap.data();
        final currentQty = (data?['currentQty'] ?? 0).toDouble();
        final cost = (data?['costPerUnit'] ?? 0).toDouble();

        tx.update(itemRef, {'currentQty': currentQty - item.quantity});

        final movementRef = _db.collection('stockMovements').doc();
        tx.set(movementRef, StockMovementModel(
          id: movementRef.id,
          type: MovementType.orderDeducted,
          itemId: item.stockItemId,
          branchId: order.branchId,
          quantity: item.quantity,
          costAtTime: cost,
          performedBy: performedBy,
          relatedOrderId: order.id,
          timestamp: DateTime.now(),
        ).toMap());
      }

      tx.update(_db.collection('orders').doc(order.id), {'status': OrderStatus.preparing.name});
    });
  }

  /// Delivery marks an order as delivered.
  Future<void> markDelivered(String orderId) async {
    await _db.collection('orders').doc(orderId).update({'status': OrderStatus.delivered.name});
  }

  /// Branch confirms receipt: increases branch stock, logs a movement at current item cost.
  Future<void> confirmReceived(OrderModel order, String performedBy) async {
    await _db.runTransaction((tx) async {
      for (final item in order.items) {
        final itemRef = _db.collection('stockItems').doc(item.stockItemId);
        final itemSnap = await tx.get(itemRef);
        final cost = (itemSnap.data()?['costPerUnit'] ?? 0).toDouble();

        final branchStockRef =
            _db.collection('branchStock').doc('${order.branchId}_${item.stockItemId}');
        final stockSnap = await tx.get(branchStockRef);
        final currentQty = (stockSnap.data()?['currentQty'] ?? 0).toDouble();

        tx.set(branchStockRef, {
          'branchId': order.branchId,
          'itemId': item.stockItemId,
          'currentQty': currentQty + item.quantity,
          'lastUpdated': DateTime.now().toIso8601String(),
        });

        final movementRef = _db.collection('stockMovements').doc();
        tx.set(movementRef, StockMovementModel(
          id: movementRef.id,
          type: MovementType.received,
          itemId: item.stockItemId,
          branchId: order.branchId,
          quantity: item.quantity,
          costAtTime: cost,
          performedBy: performedBy,
          relatedOrderId: order.id,
          timestamp: DateTime.now(),
        ).toMap());
      }

      tx.update(_db.collection('orders').doc(order.id), {'status': OrderStatus.received.name});
    });
  }

  // ---------- BRANCH STOCK ----------

  Stream<Map<String, double>> streamBranchStock(String branchId) {
    return _db
        .collection('branchStock')
        .where('branchId', isEqualTo: branchId)
        .snapshots()
        .map((snap) => {
              for (final doc in snap.docs)
                doc.data()['itemId'] as String:
                    (doc.data()['currentQty'] ?? 0).toDouble()
            });
  }

  /// Branch staff logs daily sold/wasted quantities for an item.
  Future<void> logDailyUsage({
    required String branchId,
    required String itemId,
    required double soldQty,
    required double wastedQty,
    required String performedBy,
  }) async {
    final itemRef = _db.collection('stockItems').doc(itemId);
    final branchStockRef = _db.collection('branchStock').doc('${branchId}_$itemId');

    await _db.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      final cost = (itemSnap.data()?['costPerUnit'] ?? 0).toDouble();

      final stockSnap = await tx.get(branchStockRef);
      final currentQty = (stockSnap.data()?['currentQty'] ?? 0).toDouble();
      final newQty = currentQty - soldQty - wastedQty;

      tx.update(branchStockRef, {
        'currentQty': newQty < 0 ? 0 : newQty,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      if (soldQty > 0) {
        final soldRef = _db.collection('stockMovements').doc();
        tx.set(soldRef, StockMovementModel(
          id: soldRef.id,
          type: MovementType.sold,
          itemId: itemId,
          branchId: branchId,
          quantity: soldQty,
          costAtTime: cost,
          performedBy: performedBy,
          timestamp: DateTime.now(),
        ).toMap());
      }

      if (wastedQty > 0) {
        final wastedRef = _db.collection('stockMovements').doc();
        tx.set(wastedRef, StockMovementModel(
          id: wastedRef.id,
          type: MovementType.wasted,
          itemId: itemId,
          branchId: branchId,
          quantity: wastedQty,
          costAtTime: cost,
          performedBy: performedBy,
          timestamp: DateTime.now(),
        ).toMap());
      }
    });
  }

  // ---------- REPORTS ----------

  Stream<List<StockMovementModel>> streamMovements({
    String? branchId,
    DateTime? from,
    DateTime? to,
  }) {
    Query query = _db.collection('stockMovements');
    if (branchId != null) {
      query = query.where('branchId', isEqualTo: branchId);
    }
    if (from != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: from.toIso8601String());
    }
    if (to != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: to.toIso8601String());
    }
    return query.snapshots().map((snap) => snap.docs
        .map((doc) =>
            StockMovementModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }
}