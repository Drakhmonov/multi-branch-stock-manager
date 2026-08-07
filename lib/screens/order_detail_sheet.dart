import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/stock_item_model.dart';
import '../services/firestore_service.dart';
import '../utils/format.dart';
import '../widgets/order_status_timeline.dart';
import '../widgets/stream_error_view.dart';

/// Opens a live-updating bottom sheet with an order's items and full status
/// timeline. [initialOrder] is shown immediately (avoids a loading flash for
/// data the caller already has); the sheet then stays live via [streamOrder].
void showOrderDetailSheet(
  BuildContext context, {
  required OrderModel initialOrder,
  String? branchName,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _OrderDetailSheet(
      orderId: initialOrder.id,
      initialOrder: initialOrder,
      branchName: branchName,
    ),
  );
}

class _OrderDetailSheet extends StatefulWidget {
  final String orderId;
  final OrderModel initialOrder;
  final String? branchName;

  const _OrderDetailSheet({
    required this.orderId,
    required this.initialOrder,
    this.branchName,
  });

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  final _firestoreService = FirestoreService();
  late final Stream<OrderModel?> _orderStream = _firestoreService.streamOrder(
    widget.orderId,
  );
  late final Stream<List<StockItemModel>> _stockItemsStream = _firestoreService
      .streamStockItems();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: StreamBuilder<List<StockItemModel>>(
          stream: _stockItemsStream,
          builder: (context, stockSnapshot) {
            final catalogById = {
              for (final c in stockSnapshot.data ?? <StockItemModel>[])
                c.id: c,
            };

            return StreamBuilder<OrderModel?>(
              stream: _orderStream,
              initialData: widget.initialOrder,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 200,
                    child: StreamErrorView(error: snapshot.error),
                  );
                }
                final order = snapshot.data ?? widget.initialOrder;

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.branchName != null
                            ? 'Order — ${widget.branchName}'
                            : 'Order',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Placed by ${order.placedByName}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (order.requestedDate != null)
                        Text(
                          'Requested for ${formatRequestedDate(order.requestedDate!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (order.note != null && order.note!.isNotEmpty)
                        Text(
                          'Note: ${order.note}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        orderItemsSummary(order.items, catalogById),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      OrderStatusTimeline(order: order),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
