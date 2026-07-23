import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/adaptive_nav_shell.dart';
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
    );
  }
}
