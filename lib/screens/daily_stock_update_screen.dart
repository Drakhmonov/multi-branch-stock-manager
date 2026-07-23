import 'package:flutter/material.dart';
import '../models/stock_item_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../widgets/stream_error_view.dart';

String _heldLabel(StockItemModel item, double currentQty) {
  if (item.piecesPerPack <= 1) {
    return 'Currently held: $currentQty ${item.pieceUnit}';
  }
  final packs = (currentQty / item.piecesPerPack).toStringAsFixed(1);
  return 'Currently held: $packs ${item.packLabel}(s) '
      '($currentQty ${item.pieceUnit})';
}

class DailyStockUpdateScreen extends StatefulWidget {
  final UserModel currentUser;

  const DailyStockUpdateScreen({super.key, required this.currentUser});

  @override
  State<DailyStockUpdateScreen> createState() => _DailyStockUpdateScreenState();
}

class _DailyStockUpdateScreenState extends State<DailyStockUpdateScreen> {
  final _firestoreService = FirestoreService();
  late final Stream<List<StockItemModel>> _itemsStream = _firestoreService
      .streamStockItems();
  late final Stream<Map<String, double>> _branchStockStream = _firestoreService
      .streamBranchStock(widget.currentUser.branchId ?? 'unknown');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchId = widget.currentUser.branchId ?? 'unknown';

    return StreamBuilder<List<StockItemModel>>(
      stream: _itemsStream,
      builder: (context, itemsSnapshot) {
        if (itemsSnapshot.hasError) {
          return StreamErrorView(error: itemsSnapshot.error);
        }
        if (!itemsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = itemsSnapshot.data!;

        return StreamBuilder<Map<String, double>>(
          stream: _branchStockStream,
          builder: (context, stockSnapshot) {
            if (stockSnapshot.hasError) {
              return StreamErrorView(error: stockSnapshot.error);
            }
            final branchStock = stockSnapshot.data ?? {};

            final heldItems = items
                .where((item) => (branchStock[item.id] ?? 0) > 0)
                .toList();

            if (heldItems.isEmpty) {
              return const Center(
                child: Text('No stock held at this branch yet.'),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: heldItems.length,
                    itemBuilder: (context, index) {
                      final item = heldItems[index];
                      final currentQty = branchStock[item.id] ?? 0;
                      final isPackaged = item.piecesPerPack > 1;
                      final soldWastedLabel = isPackaged
                          ? item.packLabel
                          : null;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(_heldLabel(item, currentQty)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: soldWastedLabel != null
                                            ? 'Sold ($soldWastedLabel)'
                                            : 'Sold today',
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        final entered = double.tryParse(v) ?? 0;
                                        _sold[item.id] = isPackaged
                                            ? entered * item.piecesPerPack
                                            : entered;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: soldWastedLabel != null
                                            ? 'Wasted ($soldWastedLabel)'
                                            : 'Wasted today',
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        final entered = double.tryParse(v) ?? 0;
                                        _wasted[item.id] = isPackaged
                                            ? entered * item.piecesPerPack
                                            : entered;
                                      },
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
    );
  }
}
