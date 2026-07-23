import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/format.dart';
import '../widgets/confirm_with_note_dialog.dart';
import '../widgets/responsive_body.dart';
import '../widgets/stream_error_view.dart';
import 'order_detail_sheet.dart';

class DeliveryScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onSignOut;

  const DeliveryScreen({
    super.key,
    required this.currentUser,
    required this.onSignOut,
  });

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _firestoreService = FirestoreService();
  late final Stream<Map<String, String>> _branchNamesStream = _firestoreService
      .streamBranchNames();
  late final Stream<List<OrderModel>> _ordersStream = _firestoreService
      .streamOrders();
  final Set<String> _processingIds = {};

  Future<void> _handleDeliver(OrderModel order) async {
    final note = await showConfirmWithNoteDialog(
      context,
      title: 'Mark Delivered',
      actionLabel: 'Mark Delivered',
    );
    if (note == null) return;

    setState(() => _processingIds.add(order.id));
    try {
      await _firestoreService.markDelivered(
        order.id,
        widget.currentUser.name,
        note: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked as delivered.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update order: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await AuthService().signOut();
              widget.onSignOut();
            },
          ),
        ],
      ),
      body: ResponsiveBody(
        child: StreamBuilder<Map<String, String>>(
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

                final readyForDelivery = snapshot.data!
                    .where((o) => o.status == OrderStatus.preparing)
                    .toList();
                final delivered = snapshot.data!
                    .where((o) => o.status == OrderStatus.delivered)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      'Ready for delivery (${readyForDelivery.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (readyForDelivery.isEmpty)
                      const Text('Nothing ready yet.'),
                    ...readyForDelivery.map(
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
                                : () => _handleDeliver(order),
                            child: _processingIds.contains(order.id)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Mark Delivered'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Recently delivered (${delivered.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (delivered.isEmpty) const Text('No deliveries yet.'),
                    ...delivered.map(
                      (order) => Card(
                        color: Colors.green[50],
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
                          trailing: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
