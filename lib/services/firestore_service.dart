import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch_model.dart';
import '../models/stock_item_model.dart';
import '../models/order_model.dart';
import '../models/stock_movement_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ---------- BRANCHES ----------

  Stream<List<BranchModel>> streamBranches() {
    return _db
        .collection('branches')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => BranchModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addBranch({
    required String name,
    required String location,
  }) async {
    final branchRef = _db.collection('branches').doc();
    await branchRef.set(
      BranchModel(id: branchRef.id, name: name, location: location).toMap(),
    );
  }

  /// Maps branchId -> branch name, for resolving ids on order/report screens.
  Stream<Map<String, String>> streamBranchNames() {
    return streamBranches().map(
      (branches) => {for (final b in branches) b.id: b.name},
    );
  }

  // ---------- STOCK ITEMS (central) ----------

  Stream<List<StockItemModel>> streamStockItems() {
    return _db
        .collection('stockItems')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => StockItemModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Adds a new catalog item. [initialPacks] (default 0) seeds central stock
  /// via the pack composition, same conversion [restock] uses.
  Future<void> addStockItem({
    required String name,
    required String pieceUnit,
    required String packLabel,
    required double piecesPerPack,
    required double costPerPack,
    required double reorderThreshold,
    double initialPacks = 0,
  }) async {
    final itemRef = _db.collection('stockItems').doc();
    final costPerUnit = piecesPerPack == 0 ? 0.0 : costPerPack / piecesPerPack;
    await itemRef.set(
      StockItemModel(
        id: itemRef.id,
        name: name,
        pieceUnit: pieceUnit,
        packLabel: packLabel,
        piecesPerPack: piecesPerPack,
        costPerPack: costPerPack,
        costPerUnit: costPerUnit,
        currentQty: initialPacks * piecesPerPack,
        reorderThreshold: reorderThreshold,
        lastUpdated: DateTime.now(),
      ).toMap(),
    );
  }

  /// Metadata-only edit: name/units/pack composition/reorder threshold.
  /// Never touches quantity, cost, or the ledger — use [restock] for that.
  Future<void> updateStockItemDetails({
    required String itemId,
    required String name,
    required String pieceUnit,
    required String packLabel,
    required double piecesPerPack,
    required double reorderThreshold,
  }) async {
    await _db.collection('stockItems').doc(itemId).update({
      'name': name,
      'pieceUnit': pieceUnit,
      'packLabel': packLabel,
      'piecesPerPack': piecesPerPack,
      'reorderThreshold': reorderThreshold,
    });
  }

  Future<void> deleteStockItem(String itemId) async {
    await _db.collection('stockItems').doc(itemId).delete();
  }

  /// Central kitchen receives a supplier delivery: converts packs to pieces
  /// via the item's piecesPerPack, increases central quantity, updates cost,
  /// and logs a movement (quantity/cost always in pieces, matching every
  /// other movement type).
  Future<void> restock({
    required String itemId,
    required double packsReceived,
    required double costPerPack,
    required String performedBy,
  }) async {
    final itemRef = _db.collection('stockItems').doc(itemId);
    final movementRef = _db.collection('stockMovements').doc();

    await _db.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      final data = itemSnap.data();
      final currentQty = (data?['currentQty'] ?? 0).toDouble();
      final piecesPerPack = (data?['piecesPerPack'] ?? 1).toDouble();
      final piecesReceived = packsReceived * piecesPerPack;
      final costPerUnit = piecesPerPack == 0
          ? 0.0
          : costPerPack / piecesPerPack;

      tx.update(itemRef, {
        'currentQty': currentQty + piecesReceived,
        'costPerUnit': costPerUnit,
        'costPerPack': costPerPack,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      tx.set(
        movementRef,
        StockMovementModel(
          id: movementRef.id,
          type: MovementType.restock,
          itemId: itemId,
          branchId: null,
          quantity: piecesReceived,
          costAtTime: costPerUnit,
          performedBy: performedBy,
          timestamp: DateTime.now(),
        ).toMap(),
      );
    });
  }

  // ---------- ORDERS ----------

  Future<void> placeOrder({
    required String branchId,
    required List<OrderItem> items,
    required String performedByName,
    String? note,
  }) async {
    final orderRef = _db.collection('orders').doc();
    await orderRef.set(
      OrderModel(
        id: orderRef.id,
        branchId: branchId,
        items: items,
        status: OrderStatus.requested,
        createdAt: DateTime.now(),
        placedByName: performedByName,
        note: note,
      ).toMap(),
    );
  }

  Stream<List<OrderModel>> streamOrders({String? branchId}) {
    Query query = _db
        .collection('orders')
        .orderBy('createdAt', descending: true);
    if (branchId != null) {
      query = query.where('branchId', isEqualTo: branchId);
    }
    return query.snapshots().map(
      (snap) => snap.docs
          .map(
            (doc) =>
                OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Live view of a single order, for the order detail sheet — keeps
  /// updating in real time independent of whatever list stream is driving
  /// the screen it was opened from.
  Stream<OrderModel?> streamOrder(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots().map(
      (doc) => doc.exists ? OrderModel.fromMap(doc.id, doc.data()!) : null,
    );
  }

  /// Kitchen prepares an order: deducts central stock for each item, marks it preparing.
  /// [editedItems] is the (possibly quantity-adjusted, possibly extended with
  /// items not originally requested) list kitchen confirmed in the prepare
  /// dialog — every line must already have `fulfilledQuantity` set. Stock is
  /// deducted by `fulfilledQuantity`, not the original `quantity`, and the
  /// edited list is persisted back onto the order so later steps (and the
  /// detail view) see what was actually sent.
  /// Reads every item doc first, then writes — Firestore transactions
  /// reject any read that happens after a write in the same transaction,
  /// which an interleaved read/write-per-item loop hits as soon as an
  /// order has more than one item.
  Future<void> prepareOrder(
    OrderModel order,
    List<OrderItem> editedItems,
    String performedBy,
    String performedByName, {
    String? note,
  }) async {
    await _db.runTransaction((tx) async {
      final itemRefs = editedItems
          .map((item) => _db.collection('stockItems').doc(item.stockItemId))
          .toList();
      final itemSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in itemRefs) {
        itemSnaps.add(await tx.get(ref));
      }

      for (var i = 0; i < editedItems.length; i++) {
        final item = editedItems[i];
        final fulfilledQty = item.fulfilledQuantity ?? item.quantity;
        final data = itemSnaps[i].data();
        final currentQty = (data?['currentQty'] ?? 0).toDouble();
        final cost = (data?['costPerUnit'] ?? 0).toDouble();

        tx.update(itemRefs[i], {'currentQty': currentQty - fulfilledQty});

        final movementRef = _db.collection('stockMovements').doc();
        tx.set(
          movementRef,
          StockMovementModel(
            id: movementRef.id,
            type: MovementType.orderDeducted,
            itemId: item.stockItemId,
            branchId: order.branchId,
            quantity: fulfilledQty,
            costAtTime: cost,
            performedBy: performedBy,
            relatedOrderId: order.id,
            timestamp: DateTime.now(),
          ).toMap(),
        );
      }

      tx.update(_db.collection('orders').doc(order.id), {
        'status': OrderStatus.preparing.name,
        'items': editedItems.map((i) => i.toMap()).toList(),
        'preparingAt': DateTime.now().toIso8601String(),
        'preparedByName': performedByName,
        if (note != null && note.isNotEmpty) 'preparingNote': note,
      });
    });
  }

  /// Delivery marks an order as delivered.
  Future<void> markDelivered(
    String orderId,
    String performedByName, {
    String? note,
  }) async {
    await _db.collection('orders').doc(orderId).update({
      'status': OrderStatus.delivered.name,
      'deliveredAt': DateTime.now().toIso8601String(),
      'deliveredByName': performedByName,
      if (note != null && note.isNotEmpty) 'deliveredNote': note,
    });
  }

  /// Branch confirms receipt: increases branch stock, logs a movement at
  /// current item cost. Same all-reads-then-all-writes structure as
  /// [prepareOrder], for the same reason.
  Future<void> confirmReceived(
    OrderModel order,
    String performedBy,
    String performedByName, {
    String? note,
  }) async {
    await _db.runTransaction((tx) async {
      final itemSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      final stockSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      final branchStockRefs = <DocumentReference<Map<String, dynamic>>>[];

      for (final item in order.items) {
        final itemRef = _db.collection('stockItems').doc(item.stockItemId);
        itemSnaps.add(await tx.get(itemRef));

        final branchStockRef = _db
            .collection('branchStock')
            .doc('${order.branchId}_${item.stockItemId}');
        branchStockRefs.add(branchStockRef);
        stockSnaps.add(await tx.get(branchStockRef));
      }

      for (var i = 0; i < order.items.length; i++) {
        final item = order.items[i];
        final fulfilledQty = item.fulfilledQuantity ?? item.quantity;
        final cost = (itemSnaps[i].data()?['costPerUnit'] ?? 0).toDouble();
        final currentQty = (stockSnaps[i].data()?['currentQty'] ?? 0)
            .toDouble();

        tx.set(branchStockRefs[i], {
          'branchId': order.branchId,
          'itemId': item.stockItemId,
          'currentQty': currentQty + fulfilledQty,
          'lastUpdated': DateTime.now().toIso8601String(),
        });

        final movementRef = _db.collection('stockMovements').doc();
        tx.set(
          movementRef,
          StockMovementModel(
            id: movementRef.id,
            type: MovementType.received,
            itemId: item.stockItemId,
            branchId: order.branchId,
            quantity: fulfilledQty,
            costAtTime: cost,
            performedBy: performedBy,
            relatedOrderId: order.id,
            timestamp: DateTime.now(),
          ).toMap(),
        );
      }

      tx.update(_db.collection('orders').doc(order.id), {
        'status': OrderStatus.received.name,
        'receivedAt': DateTime.now().toIso8601String(),
        'receivedByName': performedByName,
        if (note != null && note.isNotEmpty) 'receivedNote': note,
      });
    });
  }

  // ---------- BRANCH STOCK ----------

  Stream<Map<String, double>> streamBranchStock(String branchId) {
    return _db
        .collection('branchStock')
        .where('branchId', isEqualTo: branchId)
        .snapshots()
        .map(
          (snap) => {
            for (final doc in snap.docs)
              doc.data()['itemId'] as String: (doc.data()['currentQty'] ?? 0)
                  .toDouble(),
          },
        );
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
    final branchStockRef = _db
        .collection('branchStock')
        .doc('${branchId}_$itemId');

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
        tx.set(
          soldRef,
          StockMovementModel(
            id: soldRef.id,
            type: MovementType.sold,
            itemId: itemId,
            branchId: branchId,
            quantity: soldQty,
            costAtTime: cost,
            performedBy: performedBy,
            timestamp: DateTime.now(),
          ).toMap(),
        );
      }

      if (wastedQty > 0) {
        final wastedRef = _db.collection('stockMovements').doc();
        tx.set(
          wastedRef,
          StockMovementModel(
            id: wastedRef.id,
            type: MovementType.wasted,
            itemId: itemId,
            branchId: branchId,
            quantity: wastedQty,
            costAtTime: cost,
            performedBy: performedBy,
            timestamp: DateTime.now(),
          ).toMap(),
        );
      }
    });
  }

  /// Branch staff corrects a past mistake without editing history: logs a
  /// signed adjustment (positive restores stock, negative removes more) and
  /// applies it to branch stock. The original wrong entry and this fix both
  /// stay visible in the ledger.
  Future<void> logAdjustment({
    required String branchId,
    required String itemId,
    required double delta,
    required String note,
    required String performedBy,
  }) async {
    final itemRef = _db.collection('stockItems').doc(itemId);
    final branchStockRef = _db
        .collection('branchStock')
        .doc('${branchId}_$itemId');

    await _db.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      final cost = (itemSnap.data()?['costPerUnit'] ?? 0).toDouble();

      final stockSnap = await tx.get(branchStockRef);
      final currentQty = (stockSnap.data()?['currentQty'] ?? 0).toDouble();
      final newQty = currentQty + delta;

      tx.update(branchStockRef, {
        'currentQty': newQty < 0 ? 0 : newQty,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      final adjustmentRef = _db.collection('stockMovements').doc();
      tx.set(
        adjustmentRef,
        StockMovementModel(
          id: adjustmentRef.id,
          type: MovementType.adjustment,
          itemId: itemId,
          branchId: branchId,
          quantity: delta,
          costAtTime: cost,
          performedBy: performedBy,
          timestamp: DateTime.now(),
          note: note,
        ).toMap(),
      );
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
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: from.toIso8601String(),
      );
    }
    if (to != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: to.toIso8601String(),
      );
    }
    return query.snapshots().map(
      (snap) => snap.docs
          .map(
            (doc) => StockMovementModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}
