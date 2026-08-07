import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/stock_item_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/format.dart';
import '../utils/order_status.dart';
import '../widgets/adaptive_nav_shell.dart';
import '../widgets/confirm_with_note_dialog.dart';
import '../widgets/stream_error_view.dart';
import 'order_detail_sheet.dart';
import 'stock_catalog_screen.dart';

class KitchenDashboardScreen extends StatelessWidget {
  final UserModel currentUser;
  final VoidCallback onSignOut;

  const KitchenDashboardScreen({
    super.key,
    required this.currentUser,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavShell(
      subtitle: currentUser.name,
      onSignOut: () async {
        await AuthService().signOut();
        onSignOut();
      },
      destinations: [
        NavDestination(
          label: 'Orders',
          icon: Icons.receipt_long,
          contentBuilder: (_) => _KitchenOrdersBody(currentUser: currentUser),
        ),
        NavDestination(
          label: 'Stock Catalog',
          icon: Icons.inventory_2,
          contentBuilder: (_) => StockCatalogScreen(currentUser: currentUser),
        ),
        NavDestination(
          label: 'History',
          icon: Icons.history,
          contentBuilder: (_) => const _KitchenHistoryBody(),
        ),
      ],
    );
  }
}

bool _isPackaged(StockItemModel? item) => item != null && item.piecesPerPack > 1;

String _withDateSuffix(String label, OrderModel order) {
  final date = order.requestedDate;
  if (date == null) return label;
  return '$label — for ${formatRequestedDate(date)}';
}

/// "By `person`", the note (if any), then the existing item summary — so
/// kitchen sees who ordered and any special instructions without having to
/// open the detail sheet for every order.
String _orderCardSubtitle(
  OrderModel order,
  Map<String, StockItemModel> catalogById,
) {
  final lines = ['By ${order.placedByName}'];
  final note = order.note;
  if (note != null && note.isNotEmpty) lines.add('Note: $note');
  lines.add(orderItemsSummary(order.items, catalogById));
  return lines.join('\n');
}

/// The quantity shown/entered in the prepare dialog's fields is in packs for
/// a packaged item (matching how the branch ordered it), pieces otherwise.
String _inputQtyFromPieces(double pieces, StockItemModel? stockItem) {
  if (!_isPackaged(stockItem)) return pieces.toStringAsFixed(0);
  final packs = pieces / stockItem!.piecesPerPack;
  return packs == packs.roundToDouble()
      ? packs.toStringAsFixed(0)
      : packs.toStringAsFixed(1);
}

double _piecesFromInput(
  String text,
  StockItemModel? stockItem,
  double fallbackPieces,
) {
  final entered = double.tryParse(text.trim());
  if (entered == null) return fallbackPieces;
  return _isPackaged(stockItem) ? entered * stockItem!.piecesPerPack : entered;
}

class _AddedLine {
  final StockItemModel stockItem;
  final TextEditingController qtyController;

  _AddedLine({required this.stockItem, required this.qtyController});
}

class _KitchenOrdersBody extends StatefulWidget {
  final UserModel currentUser;

  const _KitchenOrdersBody({required this.currentUser});

  @override
  State<_KitchenOrdersBody> createState() => _KitchenOrdersBodyState();
}

class _KitchenOrdersBodyState extends State<_KitchenOrdersBody> {
  final _firestoreService = FirestoreService();
  late final Stream<Map<String, String>> _branchNamesStream = _firestoreService
      .streamBranchNames();
  late final Stream<List<OrderModel>> _ordersStream = _firestoreService
      .streamOrders();
  late final Stream<List<StockItemModel>> _stockItemsStream = _firestoreService
      .streamStockItems();
  final Set<String> _processingIds = {};

  Future<(List<OrderItem>, String?)?> _showReadyToDeliverDialog(
    OrderModel order,
    List<StockItemModel> catalog,
  ) {
    final catalogById = {for (final c in catalog) c.id: c};
    final qtyControllers = {
      for (final item in order.items)
        item.stockItemId: TextEditingController(
          text: _inputQtyFromPieces(
            item.quantity,
            catalogById[item.stockItemId],
          ),
        ),
    };
    final addedLines = <_AddedLine>[];
    final noteController = TextEditingController();
    String? addSelection;

    return showDialog<(List<OrderItem>, String?)>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final availableToAdd = catalog
                .where(
                  (c) => !order.items.any((i) => i.stockItemId == c.id),
                )
                .where((c) => !addedLines.any((l) => l.stockItem.id == c.id))
                .toList();

            void submit() {
              final editedItems = <OrderItem>[
                for (final item in order.items)
                  OrderItem(
                    stockItemId: item.stockItemId,
                    name: item.name,
                    quantity: item.quantity,
                    fulfilledQuantity: _piecesFromInput(
                      qtyControllers[item.stockItemId]!.text,
                      catalogById[item.stockItemId],
                      item.quantity,
                    ),
                  ),
                for (final line in addedLines)
                  OrderItem(
                    stockItemId: line.stockItem.id,
                    name: line.stockItem.name,
                    quantity: 0,
                    fulfilledQuantity: _piecesFromInput(
                      line.qtyController.text,
                      line.stockItem,
                      0,
                    ),
                  ),
              ];
              Navigator.of(
                dialogContext,
              ).pop((editedItems, noteController.text.trim()));
            }

            return AlertDialog(
              title: const Text('Ready to Deliver'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requested items',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name),
                                    Text(
                                      'Requested: ${formatItemQty(item.quantity, catalogById[item.stockItemId])}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: qtyControllers[item.stockItemId],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: _isPackaged(
                                          catalogById[item.stockItemId],
                                        )
                                        ? catalogById[item.stockItemId]!
                                              .packLabel
                                        : 'Sending',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (addedLines.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Added items',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        for (final line in addedLines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text(line.stockItem.name)),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: line.qtyController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: _isPackaged(line.stockItem)
                                          ? line.stockItem.packLabel
                                          : 'Qty',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setDialogState(
                                    () => addedLines.remove(line),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 8),
                      if (availableToAdd.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: addSelection,
                                decoration: const InputDecoration(
                                  labelText: 'Add item not requested',
                                ),
                                items: availableToAdd
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (id) =>
                                    setDialogState(() => addSelection = id),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: addSelection == null
                                  ? null
                                  : () {
                                      final item = catalog.firstWhere(
                                        (c) => c.id == addSelection,
                                      );
                                      setDialogState(() {
                                        addedLines.add(
                                          _AddedLine(
                                            stockItem: item,
                                            qtyController:
                                                TextEditingController(
                                                  text: '0',
                                                ),
                                          ),
                                        );
                                        addSelection = null;
                                      });
                                    },
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Ready to Deliver'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleStartPreparing(OrderModel order) async {
    final note = await showConfirmWithNoteDialog(
      context,
      title: 'Start Preparing',
      actionLabel: 'Start Preparing',
    );
    if (note == null) return;

    setState(() => _processingIds.add(order.id));
    try {
      await _firestoreService.startPreparing(
        order.id,
        widget.currentUser.name,
        note: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked as preparing.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(order.id));
    }
  }

  Future<void> _handleReadyToDeliver(
    OrderModel order,
    List<StockItemModel> catalog,
  ) async {
    final result = await _showReadyToDeliverDialog(order, catalog);
    if (result == null) return;
    final (editedItems, note) = result;

    setState(() => _processingIds.add(order.id));
    try {
      await _firestoreService.markPrepared(
        order,
        editedItems,
        widget.currentUser.id,
        widget.currentUser.name,
        note: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as prepared. Stock deducted.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to prepare order: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockItemModel>>(
      stream: _stockItemsStream,
      builder: (context, stockSnapshot) {
        final catalog = stockSnapshot.data ?? <StockItemModel>[];
        final catalogById = {for (final c in catalog) c.id: c};

        return StreamBuilder<Map<String, String>>(
          stream: _branchNamesStream,
          builder: (context, branchSnapshot) {
            final branchNames = branchSnapshot.data ?? <String, String>{};

            return StreamBuilder<List<OrderModel>>(
              stream: _ordersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return StreamErrorView(error: snapshot.error);
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No orders yet.'));
                }

                final requested = snapshot.data!
                    .where((o) => o.status == OrderStatus.requested)
                    .toList();
                final preparing = snapshot.data!
                    .where((o) => o.status == OrderStatus.preparing)
                    .toList();
                final prepared = snapshot.data!
                    .where((o) => o.status == OrderStatus.prepared)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      'Requested (${requested.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (requested.isEmpty) const Text('No pending requests.'),
                    ...requested.map(
                      (order) => Card(
                        child: ListTile(
                          onTap: () => showOrderDetailSheet(
                            context,
                            initialOrder: order,
                            branchName: branchNames[order.branchId],
                          ),
                          isThreeLine: true,
                          title: Text(
                            _withDateSuffix(
                              'Branch: ${branchNames[order.branchId] ?? order.branchId}',
                              order,
                            ),
                          ),
                          subtitle: Text(_orderCardSubtitle(order, catalogById)),
                          trailing: ElevatedButton(
                            onPressed: _processingIds.contains(order.id)
                                ? null
                                : () => _handleStartPreparing(order),
                            child: _processingIds.contains(order.id)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Start Preparing'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Preparing (${preparing.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (preparing.isEmpty)
                      const Text('Nothing in preparation.'),
                    ...preparing.map(
                      (order) => Card(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        child: ListTile(
                          onTap: () => showOrderDetailSheet(
                            context,
                            initialOrder: order,
                            branchName: branchNames[order.branchId],
                          ),
                          isThreeLine: true,
                          title: Text(
                            _withDateSuffix(
                              'Branch: ${branchNames[order.branchId] ?? order.branchId}',
                              order,
                            ),
                          ),
                          subtitle: Text(_orderCardSubtitle(order, catalogById)),
                          trailing: ElevatedButton(
                            onPressed: _processingIds.contains(order.id)
                                ? null
                                : () => _handleReadyToDeliver(order, catalog),
                            child: _processingIds.contains(order.id)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Ready to Deliver'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Prepared / awaiting delivery (${prepared.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (prepared.isEmpty) const Text('Nothing ready yet.'),
                    ...prepared.map(
                      (order) => Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: ListTile(
                          onTap: () => showOrderDetailSheet(
                            context,
                            initialOrder: order,
                            branchName: branchNames[order.branchId],
                          ),
                          isThreeLine: true,
                          title: Text(
                            _withDateSuffix(
                              'Branch: ${branchNames[order.branchId] ?? order.branchId}',
                              order,
                            ),
                          ),
                          subtitle: Text(_orderCardSubtitle(order, catalogById)),
                          trailing: const Text('Awaiting delivery'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Delivered/received orders — once an order moved past "prepared", it
/// simply stopped appearing anywhere in the kitchen's Orders tab (which only
/// ever shows the three active-work statuses). This gives kitchen a place to
/// look an order up after it's left their hands.
class _KitchenHistoryBody extends StatefulWidget {
  const _KitchenHistoryBody();

  @override
  State<_KitchenHistoryBody> createState() => _KitchenHistoryBodyState();
}

class _KitchenHistoryBodyState extends State<_KitchenHistoryBody> {
  final _firestoreService = FirestoreService();
  late final Stream<Map<String, String>> _branchNamesStream = _firestoreService
      .streamBranchNames();
  late final Stream<List<OrderModel>> _ordersStream = _firestoreService
      .streamOrders();
  late final Stream<List<StockItemModel>> _stockItemsStream = _firestoreService
      .streamStockItems();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockItemModel>>(
      stream: _stockItemsStream,
      builder: (context, stockSnapshot) {
        final catalogById = {
          for (final c in stockSnapshot.data ?? <StockItemModel>[]) c.id: c,
        };

        return StreamBuilder<Map<String, String>>(
          stream: _branchNamesStream,
          builder: (context, branchSnapshot) {
            final branchNames = branchSnapshot.data ?? <String, String>{};

            return StreamBuilder<List<OrderModel>>(
              stream: _ordersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return StreamErrorView(error: snapshot.error);
                }

                final history = (snapshot.data ?? [])
                    .where(
                      (o) =>
                          o.status == OrderStatus.delivered ||
                          o.status == OrderStatus.received,
                    )
                    .toList();

                if (history.isEmpty) {
                  return const Center(
                    child: Text('No delivered orders yet.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final order = history[index];
                    final branchName =
                        branchNames[order.branchId] ?? order.branchId;
                    return Card(
                      color: orderStatusColor(context, order.status),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => showOrderDetailSheet(
                          context,
                          initialOrder: order,
                          branchName: branchName,
                        ),
                        isThreeLine: true,
                        title: Text(_withDateSuffix(branchName, order)),
                        subtitle: Text(_orderCardSubtitle(order, catalogById)),
                        trailing: Text(orderStatusLabel(order.status)),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
