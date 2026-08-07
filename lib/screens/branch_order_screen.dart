import 'package:flutter/material.dart';
import '../models/stock_item_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/format.dart';
import '../widgets/stream_error_view.dart';
import '../widgets/stock_item_thumbnail.dart';

class BranchOrderScreen extends StatefulWidget {
  final UserModel currentUser;

  const BranchOrderScreen({super.key, required this.currentUser});

  @override
  State<BranchOrderScreen> createState() => _BranchOrderScreenState();
}

String _availableLabel(StockItemModel item) {
  if (item.piecesPerPack <= 1) {
    return 'Available centrally: ${formatQty(item.currentQty)} ${item.pieceUnit}';
  }
  final packs = (item.currentQty / item.piecesPerPack).toStringAsFixed(1);
  return 'Available centrally: $packs ${item.packLabel}(s) '
      '(${formatQty(item.currentQty)} ${item.pieceUnit})';
}

class _BranchOrderScreenState extends State<BranchOrderScreen> {
  final _firestoreService = FirestoreService();
  late final Stream<List<StockItemModel>> _itemsStream = _firestoreService
      .streamStockItems();
  final Map<String, double> _requestedQuantities = {};
  final _noteController = TextEditingController();
  bool _isSubmitting = false;
  String _searchQuery = '';

  Future<void> _submitOrder(List<StockItemModel> items) async {
    final orderItems = _requestedQuantities.entries
        .where((e) => e.value > 0)
        .map((e) {
          final item = items.firstWhere((i) => i.id == e.key);
          return OrderItem(
            stockItemId: item.id,
            name: item.name,
            quantity: e.value,
          );
        })
        .toList();

    if (orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a quantity for at least one item.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _firestoreService.placeOrder(
        branchId: widget.currentUser.branchId ?? 'unknown',
        items: orderItems,
        performedByName: widget.currentUser.name,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      setState(() {
        _requestedQuantities.clear();
        _noteController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order submitted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit order: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockItemModel>>(
      stream: _itemsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return StreamErrorView(error: snapshot.error);
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No stock items available yet.'));
        }

        final items = snapshot.data!;
        final filteredItems = _searchQuery.isEmpty
            ? items
            : items
                  .where(
                    (i) => i.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
                  )
                  .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search items',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(child: Text('No items match your search.'))
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isPackaged = item.piecesPerPack > 1;
                        return ListTile(
                          leading: StockItemThumbnail(
                            imageBase64: item.imageBase64,
                          ),
                          title: Text(item.name),
                          subtitle: Text(_availableLabel(item)),
                          trailing: SizedBox(
                            width: 100,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isPackaged ? item.packLabel : 'Qty',
                              ),
                              onChanged: (value) {
                                final entered = double.tryParse(value) ?? 0;
                                _requestedQuantities[item.id] = isPackaged
                                    ? entered * item.piecesPerPack
                                    : entered;
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _submitOrder(items),
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : const Text('Submit Order'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
