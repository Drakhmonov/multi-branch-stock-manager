import 'package:flutter/material.dart';
import '../models/stock_item_model.dart';
import '../models/stock_movement_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/format.dart';
import '../widgets/stream_error_view.dart';

String _labelFor(MovementType type) {
  switch (type) {
    case MovementType.sold:
      return 'Sold';
    case MovementType.wasted:
      return 'Wasted';
    case MovementType.received:
      return 'Received delivery';
    case MovementType.adjustment:
      return 'Correction';
    case MovementType.restock:
      return 'Restock';
    case MovementType.orderDeducted:
      return 'Order deducted';
    case MovementType.delivered:
      return 'Delivered';
  }
}

IconData _iconFor(MovementType type) {
  switch (type) {
    case MovementType.sold:
      return Icons.point_of_sale;
    case MovementType.wasted:
      return Icons.delete_outline;
    case MovementType.received:
      return Icons.local_shipping;
    case MovementType.adjustment:
      return Icons.build_outlined;
    default:
      return Icons.swap_horiz;
  }
}

class BranchHistoryScreen extends StatefulWidget {
  final UserModel currentUser;

  const BranchHistoryScreen({super.key, required this.currentUser});

  @override
  State<BranchHistoryScreen> createState() => _BranchHistoryScreenState();
}

class _BranchHistoryScreenState extends State<BranchHistoryScreen> {
  final _firestoreService = FirestoreService();
  late final Stream<List<StockItemModel>> _itemsStream = _firestoreService
      .streamStockItems();
  late final Stream<List<StockMovementModel>> _movementsStream =
      _firestoreService.streamMovements(
        branchId: widget.currentUser.branchId ?? 'unknown',
      );

  Future<void> _showCorrectionDialog(List<StockItemModel> items) async {
    if (items.isEmpty) return;

    String selectedItemId = items.first.id;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool addBack = true;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final amount = double.tryParse(amountController.text.trim());
              final note = noteController.text.trim();
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a positive amount.')),
                );
                return;
              }
              if (note.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Explain why you\'re making this correction.',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() => isSubmitting = true);
              try {
                await _firestoreService.logAdjustment(
                  branchId: widget.currentUser.branchId ?? 'unknown',
                  itemId: selectedItemId,
                  delta: addBack ? amount : -amount,
                  note: note,
                  performedBy: widget.currentUser.id,
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() => isSubmitting = false);
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to log correction: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Log a Correction'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedItemId,
                      decoration: const InputDecoration(labelText: 'Item'),
                      items: items
                          .map(
                            (i) => DropdownMenuItem(
                              value: i.id,
                              child: Text(i.name),
                            ),
                          )
                          .toList(),
                      onChanged: (id) =>
                          setDialogState(() => selectedItemId = id!),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Add stock back'),
                        ),
                        ButtonSegment(value: false, label: Text('Remove more')),
                      ],
                      selected: {addBack},
                      onSelectionChanged: (sel) =>
                          setDialogState(() => addBack = sel.first),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Reason (required)',
                        hintText: 'e.g. entered 50 sold by mistake, meant 5',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockItemModel>>(
      stream: _itemsStream,
      builder: (context, itemsSnapshot) {
        final items = itemsSnapshot.data ?? <StockItemModel>[];
        final itemsHasError = itemsSnapshot.hasError;
        final itemNames = {
          for (final i in items) i.id: '${i.name} (${i.pieceUnit})',
        };

        return StreamBuilder<List<StockMovementModel>>(
          stream: _movementsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return StreamErrorView(error: snapshot.error);
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Stack(
                children: [
                  const Center(child: Text('No activity logged yet.')),
                  _buildFab(items, itemsHasError),
                ],
              );
            }

            final movements = List.of(snapshot.data!)
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

            return Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: movements.length,
                  itemBuilder: (context, index) {
                    final m = movements[index];
                    final itemLabel = itemNames[m.itemId] ?? m.itemId;
                    final signedQty = m.type == MovementType.adjustment
                        ? (m.quantity > 0 ? '+${m.quantity}' : '${m.quantity}')
                        : '${m.quantity}';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(_iconFor(m.type)),
                        title: Text('${_labelFor(m.type)}: $itemLabel'),
                        subtitle: Text(
                          m.note != null && m.note!.isNotEmpty
                              ? '${formatTimestamp(m.timestamp)}\n${m.note}'
                              : formatTimestamp(m.timestamp),
                        ),
                        isThreeLine: m.note != null && m.note!.isNotEmpty,
                        trailing: Text(signedQty),
                      ),
                    );
                  },
                ),
                _buildFab(items, itemsHasError),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFab(List<StockItemModel> items, bool itemsHasError) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton.extended(
        onPressed: itemsHasError
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Couldn\'t load items — check your connection and try again.',
                  ),
                ),
              )
            : () => _showCorrectionDialog(items),
        icon: const Icon(Icons.build_outlined),
        label: const Text('Log Correction'),
      ),
    );
  }
}
