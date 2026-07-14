import 'package:flutter/material.dart';
import '../models/stock_item_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class DailyStockUpdateScreen extends StatefulWidget {
  final UserModel currentUser;

  const DailyStockUpdateScreen({super.key, required this.currentUser});

  @override
  State<DailyStockUpdateScreen> createState() => _DailyStockUpdateScreenState();
}

class _DailyStockUpdateScreenState extends State<DailyStockUpdateScreen> {
  final _firestoreService = FirestoreService();
  final Map<String, double> _sold = {};
  final Map<String, double> _wasted = {};
  bool _isSubmitting = false;

  Future<void> _submitAll(String branchId) async {
    setState(() => _isSubmitting = true);
    try {
      for (final itemId in {..._sold.keys, ..._wasted.keys}) {
        final soldQty = _sold[itemId] ?? 0;
        final wastedQty = _wasted[itemId] ?? 0;
        if (soldQty > 0 || wastedQty > 0) {
          await _firestoreService.logDailyUsage(
            branchId: branchId,
            itemId: itemId,
            soldQty: soldQty,
            wastedQty: wastedQty,
            performedBy: widget.currentUser.id,
          );
        }
      }
      setState(() {
        _sold.clear();
        _wasted.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily update submitted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchId = widget.currentUser.branchId ?? 'unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Stock Update')),
      body: StreamBuilder<List<StockItemModel>>(
        stream: _firestoreService.streamStockItems(),
        builder: (context, itemsSnapshot) {
          if (!itemsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = itemsSnapshot.data!;

          return StreamBuilder<Map<String, double>>(
            stream: _firestoreService.streamBranchStock(branchId),
            builder: (context, stockSnapshot) {
              final branchStock = stockSnapshot.data ?? {};

              final heldItems = items
                  .where((item) => (branchStock[item.id] ?? 0) > 0)
                  .toList();

              if (heldItems.isEmpty) {
                return const Center(
                    child: Text('No stock held at this branch yet.'));
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: heldItems.length,
                      itemBuilder: (context, index) {
                        final item = heldItems[index];
                        final currentQty = branchStock[item.id] ?? 0;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text('Currently held: $currentQty ${item.unit}'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        decoration: const InputDecoration(
                                            labelText: 'Sold today'),
                                        keyboardType: TextInputType.number,
                                        onChanged: (v) => _sold[item.id] =
                                            double.tryParse(v) ?? 0,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        decoration: const InputDecoration(
                                            labelText: 'Wasted today'),
                                        keyboardType: TextInputType.number,
                                        onChanged: (v) => _wasted[item.id] =
                                            double.tryParse(v) ?? 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitAll(branchId),
                        child: _isSubmitting
                            ? const CircularProgressIndicator()
                            : const Text('Submit Daily Update'),
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