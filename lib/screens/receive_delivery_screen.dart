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
  final Set<String> _processingIds = {};

  Future<void> _handleConfirm(OrderModel order) async {
    setState(() => _processingIds.add(order.id));
    try {
      await _firestoreService.confirmReceived(order, widget.currentUser.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt confirmed. Branch stock updated.')),
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
    final branchId = widget.currentUser.branchId ?? 'unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Delivery')),
      body: StreamBuilder<List<OrderModel>>(
        stream: _firestoreService.streamOrders(branchId: branchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final delivered = (snapshot.data ?? [])
              .where((o) => o.status == OrderStatus.delivered)
              .toList();

          if (delivered.isEmpty) {
            return const Center(child: Text('No deliveries waiting to be confirmed.'));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: delivered.map((order) => Card(
                  child: ListTile(
                    title: Text(order.items
                        .map((i) => '${i.name} x${i.quantity}')
                        .join(', ')),
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
                )).toList(),
          );
        },
      ),
    );
  }
}