import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/stock_item_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/format.dart';
import '../widgets/adaptive_nav_shell.dart';
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
      ],
    );
  }
}

class _AddedLine {
  final String stockItemId;
  final String name;
  final TextEditingController qtyController;

  _AddedLine({
    required this.stockItemId,
    required this.name,
    required this.qtyController,
  });
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

  Future<(List<OrderItem>, String?)?> _showPrepareDialog(
    OrderModel order,
    List<StockItemModel> catalog,
  ) {
    final qtyControllers = {
      for (final item in order.items)
        item.stockItemId: TextEditingController(
          text: item.quantity.toStringAsFixed(0),
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
                .where((c) => !addedLines.any((l) => l.stockItemId == c.id))
                .toList();

            void submit() {
              final editedItems = <OrderItem>[
                for (final item in order.items)
                  OrderItem(
                    stockItemId: item.stockItemId,
                    name: item.name,
                    quantity: item.quantity,
                    fulfilledQuantity:
                        double.tryParse(
                          qtyControllers[item.stockItemId]!.text.trim(),
                        ) ??
                        item.quantity,
                  ),
                for (final line in addedLines)
                  OrderItem(
                    stockItemId: line.stockItemId,
                    name: line.name,
                    quantity: 0,
                    fulfilledQuantity:
                        double.tryParse(line.qtyController.text.trim()) ?? 0,
                  ),
              ];
              Navigator.of(
                dialogContext,
              ).pop((editedItems, noteController.text.trim()));
            }

            return AlertDialog(
              title: const Text('Prepare Order'),
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
                              Expanded(child: Text(item.name)),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: qtyControllers[item.stockItemId],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Sending',
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
                                Expanded(child: Text(line.name)),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: line.qtyController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Qty',
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
                                            stockItemId: item.id,
                                            name: item.name,
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
                FilledButton(onPressed: submit, child: const Text('Prepare')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handlePrepare(
    OrderModel order,
    List<StockItemModel> catalog,
  ) async {
    final result = await _showPrepareDialog(order, catalog);
    if (result == null) return;
    final (editedItems, note) = result;

    setState(() => _processingIds.add(order.id));
    try {
      await _firestoreService.prepareOrder(
        order,
        editedItems,
        widget.currentUser.id,
        widget.currentUser.name,
        note: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as preparing. Stock deducted.'),
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
                          title: Text(
                            'Branch: ${branchNames[order.branchId] ?? order.branchId}',
                          ),
                          subtitle: Text(orderItemsSummary(order.items)),
                          trailing: ElevatedButton(
                            onPressed: _processingIds.contains(order.id)
                                ? null
                                : () => _handlePrepare(order, catalog),
                            child: _processingIds.contains(order.id)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Prepare'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Preparing / awaiting delivery (${preparing.length})',
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
                          title: Text(
                            'Branch: ${branchNames[order.branchId] ?? order.branchId}',
                          ),
                          subtitle: Text(orderItemsSummary(order.items)),
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
