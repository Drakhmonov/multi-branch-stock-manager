import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/stock_movement_model.dart';
import '../services/firestore_service.dart';

enum _Period { today, week, month, all }

class ManagerDashboardScreen extends StatefulWidget {
  final UserModel currentUser;

  const ManagerDashboardScreen({super.key, required this.currentUser});

  @override
  State<ManagerDashboardScreen> createState() =>
      _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final _firestoreService = FirestoreService();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Manager Dashboard')),
      body: Column(
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
              onSelectionChanged: (sel) =>
                  setState(() => _period = sel.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<StockMovementModel>>(
              stream: _firestoreService.streamMovements(from: _from),
              builder: (context, snapshot) {
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
                    0, (sum, m) => sum + m.quantity * m.costAtTime);
                final totalWastedCost = wasted.fold<double>(
                    0, (sum, m) => sum + m.quantity * m.costAtTime);
                final wasteTotal = totalSoldCost + totalWastedCost;
                final wastePct =
                    wasteTotal == 0 ? 0.0 : totalWastedCost / wasteTotal * 100;

                final branchIds = {
                  ...sold.map((m) => m.branchId),
                  ...wasted.map((m) => m.branchId),
                }.whereType<String>().toList()
                  ..sort();

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                              label: 'Sold value', value: totalSoldCost),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                              label: 'Wasted value', value: totalWastedCost),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Waste rate: ${wastePct.toStringAsFixed(1)}% of sold+wasted value',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('By branch',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (branchIds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No sold/wasted activity in this period.'),
                      )
                    else
                      ...branchIds.map((branchId) {
                        final branchSoldCost = sold
                            .where((m) => m.branchId == branchId)
                            .fold<double>(
                                0, (sum, m) => sum + m.quantity * m.costAtTime);
                        final branchWastedCost = wasted
                            .where((m) => m.branchId == branchId)
                            .fold<double>(
                                0, (sum, m) => sum + m.quantity * m.costAtTime);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(branchId),
                            subtitle: Text(
                                'Sold: £${branchSoldCost.toStringAsFixed(2)}   '
                                'Wasted: £${branchWastedCost.toStringAsFixed(2)}'),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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
            Text('£${value.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
