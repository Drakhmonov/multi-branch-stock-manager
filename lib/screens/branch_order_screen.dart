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

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class _BranchOrderScreenState extends State<BranchOrderScreen> {
  final _firestoreService = FirestoreService();
  late final Stream<List<StockItemModel>> _itemsStream = _firestoreService
      .streamStockItems();
  // Real controllers (keyed by stockItemId, created on demand) rather than a
  // separately-tracked quantities map — a bare onChanged into a map left the
  // fields showing stale text after a successful submit, since clearing the
  // map doesn't touch a TextField's own internal editing state.
  final Map<String, TextEditingController> _qtyControllers = {};
  final _noteController = TextEditingController();
  DateTime _requestedDate = _dateOnly(DateTime.now());
  bool _reviewing = false;
  bool _isSubmitting = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _noteController.dispose();
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _qtyControllerFor(String itemId) {
    return _qtyControllers.putIfAbsent(itemId, () => TextEditingController());
  }

  /// Piece quantities (packs already converted) for every item with a
  /// positive entry, read straight from each item's controller — the single
  /// source of truth for "what's been entered."
  Map<String, double> _currentQuantities(List<StockItemModel> items) {
    final result = <String, double>{};
    for (final item in items) {
      final controller = _qtyControllers[item.id];
      if (controller == null) continue;
      final entered = double.tryParse(controller.text.trim()) ?? 0;
      if (entered <= 0) continue;
      final isPackaged = item.piecesPerPack > 1;
      result[item.id] = isPackaged ? entered * item.piecesPerPack : entered;
    }
    return result;
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestedDate,
      firstDate: _dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _requestedDate = _dateOnly(picked));
    }
  }

  void _goToReview(List<StockItemModel> items) {
    if (_currentQuantities(items).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a quantity for at least one item.'),
        ),
      );
      return;
    }
    setState(() => _reviewing = true);
  }

  Future<void> _submitOrder(List<StockItemModel> items) async {
    final quantities = _currentQuantities(items);
    final orderItems = quantities.entries.map((e) {
      final item = items.firstWhere((i) => i.id == e.key);
      return OrderItem(stockItemId: item.id, name: item.name, quantity: e.value);
    }).toList();

    setState(() => _isSubmitting = true);
    final submittedDateLabel = formatRequestedDate(_requestedDate);
    try {
      await _firestoreService.placeOrder(
        branchId: widget.currentUser.branchId ?? 'unknown',
        items: orderItems,
        performedByName: widget.currentUser.name,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        requestedDate: _requestedDate,
      );
      _resetAfterSubmit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order submitted for $submittedDateLabel.')),
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

  void _resetAfterSubmit() {
    setState(() {
      for (final controller in _qtyControllers.values) {
        controller.clear();
      }
      _noteController.clear();
      _requestedDate = _dateOnly(DateTime.now());
      _reviewing = false;
    });
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
        return _reviewing
            ? _buildReviewStep(items)
            : _buildSelectStep(items);
      },
    );
  }

  Widget _buildSelectStep(List<StockItemModel> items) {
    final filteredItems = _searchQuery.isEmpty
        ? items
        : items
              .where(
                (i) =>
                    i.name.toLowerCase().contains(_searchQuery.toLowerCase()),
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
                          controller: _qtyControllerFor(item.id),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isPackaged ? item.packLabel : 'Qty',
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        ListTile(
          leading: const Icon(Icons.event_outlined),
          title: const Text('Delivery date'),
          subtitle: Text(formatRequestedDate(_requestedDate)),
          onTap: _pickDeliveryDate,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
              onPressed: () => _goToReview(items),
              child: const Text('Review Order'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(List<StockItemModel> items) {
    final catalogById = {for (final i in items) i.id: i};
    final quantities = _currentQuantities(items);
    final note = _noteController.text.trim();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review order', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(
            'Delivery: ${formatRequestedDate(_requestedDate)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Ordered by: ${widget.currentUser.name}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Note: $note',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: quantities.entries.map((e) {
                final item = catalogById[e.key];
                return ListTile(
                  leading: StockItemThumbnail(imageBase64: item?.imageBase64),
                  title: Text(item?.name ?? 'Unknown item'),
                  trailing: Text(formatItemQty(e.value, item)),
                );
              }).toList(),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _reviewing = false),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _submitOrder(items),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm & Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
