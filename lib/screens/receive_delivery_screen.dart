import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/stock_item_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/confirm_with_note_dialog.dart';
import '../widgets/stream_error_view.dart';
import 'order_detail_sheet.dart';

/// Branch staff's view of every order they've placed, across its whole
/// lifecycle — not just the ones awaiting confirmation. Previously this
/// screen only showed delivered/received orders, so a branch had no way to
/// tell whether a just-placed order was still sitting requested or already
/// being prepared.
class ReceiveDeliveryScreen extends StatefulWidget {
  final UserModel currentUser;

  const ReceiveDeliveryScreen({super.key, required this.currentUser});

  @override
  State<ReceiveDeliveryScreen> createState() => _ReceiveDeliveryScreenState();
}

class _ReceiveDeliveryScreenState extends State<ReceiveDeliveryScreen> {
  final _firestoreService = FirestoreService();
  late final Stream<List<OrderModel>> _ordersStream = _firestoreService
      .streamOrders(branchId: widget.currentUser.branchId ?? 'unknown');
  late final Stream<List<StockItemModel>> _stockItemsStream = _firestoreService
      .streamStockItems();
  final Set<String> _processingIds = {};

  Future<void> _handleConfirm(OrderModel order) async {
    final note = await showConfirmWithNoteDialog(
      context,
      title: 'Confirm Received',
      actionLabel: 'Confirm Received',
    );
    if (note == null) return;

    setState(() => _processingIds.add(order.id));
    try {
      await _firestoreService.confirmReceived(
        order,
        widget.currentUser.id,
        widget.currentUser.name,
        note: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt confirmed. Branch stock updated.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm receipt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(order.id));
    }
  }

  Widget _orderCard(
    OrderModel order,
    Map<String, StockItemModel> catalogById, {
    Color? color,
    Widget? trailing,
  }) {
    return Card(
      color: color,
      child: ListTile(
        onTap: () => showOrderDetailSheet(context, initialOrder: order),
        title: Text(orderItemsSummary(order.items, catalogById)),
        trailing: trailing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockItemModel>>(
      stream: _stockItemsStream,
      builder: (context, stockSnapshot) {
        final catalogById = {
          for (final c in stockSnapshot.data ?? <StockItemModel>[]) c.id: c,
        };

        return StreamBuilder<List<OrderModel>>(
          stream: _ordersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return StreamErrorView(error: snapshot.error);
            }

            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return const Center(child: Text('No orders yet.'));
            }

            final requested = orders
                .where((o) => o.status == OrderStatus.requested)
                .toList();
            final preparing = orders
                .where((o) => o.status == OrderStatus.preparing)
                .toList();
            final prepared = orders
                .where((o) => o.status == OrderStatus.prepared)
                .toList();
            final toReceive = orders
                .where((o) => o.status == OrderStatus.delivered)
                .toList();
            final received = orders
                .where((o) => o.status == OrderStatus.received)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  'Requested (${requested.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (requested.isEmpty) const Text('Nothing requested.'),
                ...requested.map((order) => _orderCard(order, catalogById)),
                const SizedBox(height: 24),
                Text(
                  'Preparing (${preparing.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (preparing.isEmpty) const Text('Nothing in preparation.'),
                ...preparing.map(
                  (order) => _orderCard(
                    order,
                    catalogById,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Prepared (${prepared.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (prepared.isEmpty) const Text('Nothing ready yet.'),
                ...prepared.map(
                  (order) => _orderCard(
                    order,
                    catalogById,
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Receive Order (${toReceive.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (toReceive.isEmpty) const Text('No order.'),
                ...toReceive.map(
                  (order) => _orderCard(
                    order,
                    catalogById,
                    trailing: ElevatedButton(
                      onPressed: _processingIds.contains(order.id)
                          ? null
                          : () => _handleConfirm(order),
                      child: _processingIds.contains(order.id)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirm Received'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Received Order (${received.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (received.isEmpty) const Text('No order.'),
                ...received.map((order) {
                  final statusColors = Theme.of(
                    context,
                  ).extension<StatusColors>()!;
                  return _orderCard(
                    order,
                    catalogById,
                    color: statusColors.successContainer,
                    trailing: Icon(
                      Icons.check_circle,
                      color: statusColors.onSuccessContainer,
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}
