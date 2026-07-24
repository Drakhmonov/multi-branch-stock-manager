import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../models/stock_movement_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/adaptive_nav_shell.dart';
import '../widgets/stream_error_view.dart';
import 'branch_management_screen.dart';
import 'order_detail_sheet.dart';

enum _Period { today, week, month, all }

class ManagerDashboardScreen extends StatelessWidget {
  final UserModel currentUser;
  final VoidCallback onSignOut;

  const ManagerDashboardScreen({
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
          label: 'Dashboard',
          icon: Icons.dashboard,
          contentBuilder: (_) => const _ManagerDashboardBody(),
        ),
        NavDestination(
          label: 'Orders',
          icon: Icons.receipt_long,
          contentBuilder: (_) => const _ManagerOrdersBody(),
        ),
        NavDestination(
          label: 'Branches',
          icon: Icons.store,
          contentBuilder: (_) => const BranchManagementScreen(),
        ),
      ],
    );
  }
}

class _ManagerDashboardBody extends StatefulWidget {
  const _ManagerDashboardBody();

  @override
  State<_ManagerDashboardBody> createState() => _ManagerDashboardBodyState();
}

class _ManagerDashboardBodyState extends State<_ManagerDashboardBody> {
  final _firestoreService = FirestoreService();
  late final Stream<Map<String, String>> _branchNamesStream = _firestoreService
      .streamBranchNames();
  _Period _period = _Period.week;

  DateTime? get _from {
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        return DateTime(now.year, now.month, now.day);
      case _Period.week:
        return now.subtract(const Duration(days: 7));
      case _Period.month:
        return now.subtract(const Duration(days: 30));
      case _Period.all:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<_Period>(
            segments: const [
              ButtonSegment(value: _Period.today, label: Text('Today')),
              ButtonSegment(value: _Period.week, label: Text('7 days')),
              ButtonSegment(value: _Period.month, label: Text('30 days')),
              ButtonSegment(value: _Period.all, label: Text('All time')),
            ],
            selected: {_period},
            onSelectionChanged: (sel) => setState(() => _period = sel.first),
          ),
        ),
        Expanded(
          child: StreamBuilder<Map<String, String>>(
            stream: _branchNamesStream,
            builder: (context, branchSnapshot) {
              final branchNames = branchSnapshot.data ?? <String, String>{};
              return StreamBuilder<List<StockMovementModel>>(
                stream: _firestoreService.streamMovements(from: _from),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return StreamErrorView(error: snapshot.error);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final movements = snapshot.data!;
                  final sold = movements
                      .where((m) => m.type == MovementType.sold)
                      .toList();
                  final wasted = movements
                      .where((m) => m.type == MovementType.wasted)
                      .toList();

                  final totalSoldCost = sold.fold<double>(
                    0,
                    (sum, m) => sum + m.quantity * m.costAtTime,
                  );
                  final totalWastedCost = wasted.fold<double>(
                    0,
                    (sum, m) => sum + m.quantity * m.costAtTime,
                  );
                  final wasteTotal = totalSoldCost + totalWastedCost;
                  final wastePct = wasteTotal == 0
                      ? 0.0
                      : totalWastedCost / wasteTotal * 100;

                  final branchIds = {
                    ...sold.map((m) => m.branchId),
                    ...wasted.map((m) => m.branchId),
                  }.whereType<String>().toList()..sort();

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              label: 'Sold value',
                              value: totalSoldCost,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              label: 'Wasted value',
                              value: totalWastedCost,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Waste rate: ${wastePct.toStringAsFixed(1)}% of sold+wasted value',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'By branch',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (branchIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No sold/wasted activity in this period.',
                          ),
                        )
                      else
                        ...branchIds.map((branchId) {
                          final branchSoldCost = sold
                              .where((m) => m.branchId == branchId)
                              .fold<double>(
                                0,
                                (sum, m) => sum + m.quantity * m.costAtTime,
                              );
                          final branchWastedCost = wasted
                              .where((m) => m.branchId == branchId)
                              .fold<double>(
                                0,
                                (sum, m) => sum + m.quantity * m.costAtTime,
                              );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(branchNames[branchId] ?? branchId),
                              subtitle: Text(
                                'Sold: £${branchSoldCost.toStringAsFixed(2)}   '
                                'Wasted: £${branchWastedCost.toStringAsFixed(2)}',
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ManagerOrdersBody extends StatefulWidget {
  const _ManagerOrdersBody();

  @override
  State<_ManagerOrdersBody> createState() => _ManagerOrdersBodyState();
}

class _ManagerOrdersBodyState extends State<_ManagerOrdersBody> {
  final _firestoreService = FirestoreService();
  late final Stream<Map<String, String>> _branchNamesStream = _firestoreService
      .streamBranchNames();
  late final Stream<List<OrderModel>> _ordersStream = _firestoreService
      .streamOrders();

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.requested:
        return 'Requested';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.received:
        return 'Received';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color? _statusColor(BuildContext context, OrderStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case OrderStatus.preparing:
        return scheme.tertiaryContainer;
      case OrderStatus.delivered:
        return scheme.secondaryContainer;
      case OrderStatus.received:
        return Theme.of(context).extension<StatusColors>()!.successContainer;
      case OrderStatus.requested:
      case OrderStatus.cancelled:
        return null;
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
            if (snapshot.hasError) {
              return StreamErrorView(error: snapshot.error);
            }

            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return const Center(child: Text('No orders yet.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final branchName = branchNames[order.branchId] ?? order.branchId;
                return Card(
                  color: _statusColor(context, order.status),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => showOrderDetailSheet(
                      context,
                      initialOrder: order,
                      branchName: branchName,
                    ),
                    title: Text(branchName),
                    subtitle: Text(orderItemsSummary(order.items)),
                    trailing: Text(_statusLabel(order.status)),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;

  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              '£${value.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
