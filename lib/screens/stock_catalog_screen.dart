import 'package:flutter/material.dart';
import '../models/stock_item_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/format.dart';
import '../widgets/stream_error_view.dart';

class StockCatalogScreen extends StatefulWidget {
  final UserModel currentUser;

  const StockCatalogScreen({super.key, required this.currentUser});

  @override
  State<StockCatalogScreen> createState() => _StockCatalogScreenState();
}

class _StockCatalogScreenState extends State<StockCatalogScreen> {
  final _firestoreService = FirestoreService();
  late final Stream<List<StockItemModel>> _itemsStream = _firestoreService
      .streamStockItems();
  String _searchQuery = '';

  String _packCompositionLabel(StockItemModel item) {
    if (item.piecesPerPack <= 1) return item.pieceUnit;
    return '1 ${item.packLabel} = ${item.piecesPerPack.toStringAsFixed(0)} ${item.pieceUnit}';
  }

  String _stockLabel(StockItemModel item) {
    final qty = item.currentQty;
    if (item.piecesPerPack <= 1) return '${formatQty(qty)} ${item.pieceUnit}';
    final packs = (qty / item.piecesPerPack).toStringAsFixed(1);
    return '${formatQty(qty)} ${item.pieceUnit} ($packs ${item.packLabel}s)';
  }

  Future<void> _showAddItemDialog() async {
    final nameController = TextEditingController();
    final pieceUnitController = TextEditingController();
    final packLabelController = TextEditingController();
    final piecesPerPackController = TextEditingController(text: '1');
    final costPerPackController = TextEditingController();
    final reorderThresholdController = TextEditingController(text: '0');
    final initialPacksController = TextEditingController(text: '0');
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final name = nameController.text.trim();
              final pieceUnit = pieceUnitController.text.trim();
              final packLabel = packLabelController.text.trim().isEmpty
                  ? pieceUnit
                  : packLabelController.text.trim();
              final piecesPerPack =
                  double.tryParse(piecesPerPackController.text.trim()) ?? 1;
              final costPerPack =
                  double.tryParse(costPerPackController.text.trim()) ?? 0;
              final reorderThreshold =
                  double.tryParse(reorderThresholdController.text.trim()) ?? 0;
              final initialPacks =
                  double.tryParse(initialPacksController.text.trim()) ?? 0;

              if (name.isEmpty || pieceUnit.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a name and a unit.')),
                );
                return;
              }

              setDialogState(() => isSubmitting = true);
              try {
                await _firestoreService.addStockItem(
                  name: name,
                  pieceUnit: pieceUnit,
                  packLabel: packLabel,
                  piecesPerPack: piecesPerPack,
                  costPerPack: costPerPack,
                  reorderThreshold: reorderThreshold,
                  initialPacks: initialPacks,
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() => isSubmitting = false);
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to add item: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Add Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name (e.g. Chicken Dumplings)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pieceUnitController,
                      decoration: const InputDecoration(
                        labelText: 'Piece unit (e.g. pcs, litre, bottle)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: packLabelController,
                      decoration: const InputDecoration(
                        labelText:
                            'Pack label (e.g. bag, 20L can) — leave blank if not packaged',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: piecesPerPackController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pieces per pack (1 if not packaged)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costPerPackController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cost per pack (£)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reorderThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reorder threshold (in pieces)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: initialPacksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Initial packs received (optional)',
                      ),
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
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRestockDialog(StockItemModel item) async {
    final packsController = TextEditingController();
    final costController = TextEditingController(
      text: item.costPerPack.toStringAsFixed(2),
    );
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final packs = double.tryParse(packsController.text.trim());
              final cost = double.tryParse(costController.text.trim());
              if (packs == null || packs <= 0 || cost == null || cost < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid pack count and cost.'),
                  ),
                );
                return;
              }

              setDialogState(() => isSubmitting = true);
              try {
                await _firestoreService.restock(
                  itemId: item.id,
                  packsReceived: packs,
                  costPerPack: cost,
                  performedBy: widget.currentUser.id,
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() => isSubmitting = false);
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to restock: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: Text('Restock ${item.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: packsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Packs received (${item.packLabel})',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Cost per ${item.packLabel} (£)',
                    ),
                  ),
                ],
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
                      : const Text('Restock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(StockItemModel item) async {
    final nameController = TextEditingController(text: item.name);
    final pieceUnitController = TextEditingController(text: item.pieceUnit);
    final packLabelController = TextEditingController(text: item.packLabel);
    final piecesPerPackController = TextEditingController(
      text: item.piecesPerPack.toStringAsFixed(0),
    );
    final reorderThresholdController = TextEditingController(
      text: item.reorderThreshold.toStringAsFixed(0),
    );
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              setDialogState(() => isSubmitting = true);
              try {
                await _firestoreService.updateStockItemDetails(
                  itemId: item.id,
                  name: nameController.text.trim(),
                  pieceUnit: pieceUnitController.text.trim(),
                  packLabel: packLabelController.text.trim(),
                  piecesPerPack:
                      double.tryParse(piecesPerPackController.text.trim()) ?? 1,
                  reorderThreshold:
                      double.tryParse(reorderThresholdController.text.trim()) ??
                      0,
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() => isSubmitting = false);
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Edit Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pieceUnitController,
                      decoration: const InputDecoration(
                        labelText: 'Piece unit',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: packLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Pack label',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: piecesPerPackController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pieces per pack',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reorderThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reorder threshold (pieces)',
                      ),
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
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(StockItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(
          'Remove "${item.name}" from the catalog? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteStockItem(item.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
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

        final allItems = snapshot.data ?? <StockItemModel>[];
        final items =
            (_searchQuery.isEmpty
                  ? allItems
                  : allItems
                        .where(
                          (i) => i.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        )
                        .toList())
              ..sort((a, b) => a.name.compareTo(b.name));

        return Stack(
          children: [
            Column(
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
                  child: items.isEmpty
                      ? const Center(child: Text('No items found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final lowStock =
                                item.currentQty <= item.reorderThreshold;

                            final scheme = Theme.of(context).colorScheme;
                            return Card(
                              color: lowStock ? scheme.errorContainer : null,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: lowStock
                                    ? Icon(
                                        Icons.warning_amber,
                                        color: scheme.onErrorContainer,
                                      )
                                    : const Icon(Icons.inventory_2_outlined),
                                title: Text(item.name),
                                subtitle: Text(
                                  '${_packCompositionLabel(item)}\n'
                                  'Stock: ${_stockLabel(item)}\n'
                                  'Cost: £${item.costPerPack.toStringAsFixed(2)} / ${item.packLabel}',
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'restock') {
                                      _showRestockDialog(item);
                                    } else if (action == 'edit') {
                                      _showEditDialog(item);
                                    } else if (action == 'delete') {
                                      _confirmDelete(item);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'restock',
                                      child: Text('Restock'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _showAddItemDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ),
          ],
        );
      },
    );
  }
}
