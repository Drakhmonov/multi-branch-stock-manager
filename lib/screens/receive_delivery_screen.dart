import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

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
  final Set<String> _processingIds = {};

  Future<void> _handleConfirm(OrderModel order) async {
    setState(() => _processingIds.add(order.id));
    try {
      await _firestoreService.confirmReceived(order, widget.currentUser.id);
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final relevant = (snapshot.data ?? [])
            .where(
              (o) =>
                  o.status == OrderStatus.delivered ||
                  o.status == OrderStatus.received,
            )
            .toList();

        if (relevant.isEmpty) {
          return const Center(child: Text('No order.'));
        }

        final toReceive = relevant
            .where((o) => o.status == OrderStatus.delivered)
            .toList();
        final received = relevant
            .where((o) => o.status == OrderStatus.received)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              'Receive Order (${toReceive.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (toReceive.isEmpty) const Text('No order.'),
            ...toReceive.map(
              (order) => Card(
                child: ListTile(
                  title: Text(
                    order.items
                        .map((i) => '${i.name} x${i.quantity}')
                        .join(', '),
                  ),
                  subtitle: const Text('Delivered — awaiting confirmation'),
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
            ),
            const SizedBox(height: 24),
            Text(
              'Received Order (${received.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (received.isEmpty) const Text('No order.'),
            ...received.map(
              (order) => Card(
                color: Colors.green[50],
                child: ListTile(
                  title: Text(
                    order.items
                        .map((i) => '${i.name} x${i.quantity}')
                        .join(', '),
                  ),
                  subtitle: const Text('Received — stock updated'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
