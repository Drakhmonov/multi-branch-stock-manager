import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class KitchenDashboardScreen extends StatefulWidget {
  final UserModel currentUser;

  const KitchenDashboardScreen({super.key, required this.currentUser});

  @override
  State<KitchenDashboardScreen> createState() => _KitchenDashboardScreenState();
}

class _KitchenDashboardScreenState extends State<KitchenDashboardScreen> {
  final _firestoreService = FirestoreService();
  final Set<String> _processingIds = {};

  Future<void> _handlePrepare(OrderModel order) async {
    setState(() => _processingIds.add(order.id));
    try {
      await _firestoreService.prepareOrder(order, widget.currentUser.id);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Kitchen Dashboard')),
      body: StreamBuilder<Map<String, String>>(
        stream: _firestoreService.streamBranchNames(),
        builder: (context, branchSnapshot) {
          final branchNames = branchSnapshot.data ?? <String, String>{};

          return StreamBuilder<List<OrderModel>>(
            stream: _firestoreService.streamOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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
                        title: Text(
                          'Branch: ${branchNames[order.branchId] ?? order.branchId}',
                        ),
                        subtitle: Text(
                          order.items
                              .map((i) => '${i.name} x${i.quantity}')
                              .join(', '),
                        ),
                        trailing: ElevatedButton(
                          onPressed: _processingIds.contains(order.id)
                              ? null
                              : () => _handlePrepare(order),
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
                  if (preparing.isEmpty) const Text('Nothing in preparation.'),
                  ...preparing.map(
                    (order) => Card(
                      color: Colors.amber[50],
                      child: ListTile(
                        title: Text(
                          'Branch: ${branchNames[order.branchId] ?? order.branchId}',
                        ),
                        subtitle: Text(
                          order.items
                              .map((i) => '${i.name} x${i.quantity}')
                              .join(', '),
                        ),
                        trailing: const Text('Awaiting delivery'),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
