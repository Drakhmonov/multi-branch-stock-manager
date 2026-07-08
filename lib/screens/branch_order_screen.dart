import 'package:flutter/material.dart';
import '../models/stock_item_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class BranchOrderScreen extends StatefulWidget {
  final UserModel currentUser;

  const BranchOrderScreen({super.key, required this.currentUser});

  @override
  State<BranchOrderScreen> createState() => _BranchOrderScreenState();
}

class _BranchOrderScreenState extends State<BranchOrderScreen> {
  final _firestoreService = FirestoreService();
  final Map<String, double> _requestedQuantities = {};
  bool _isSubmitting = false;

  Future<void> _submitOrder(List<StockItemModel> items) async {
    final orderItems = _requestedQuantities.entries
        .where((e) => e.value > 0)
        .map((e) {
          final item = items.firstWhere((i) => i.id == e.key);
          return OrderItem(stockItemId: item.id, name: item.name, quantity: e.value);
        })
        .toList();

    if (orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a quantity for at least one item.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _firestoreService.placeOrder(
        branchId: widget.currentUser.branchId ?? 'unknown',
        items: orderItems,
      );
      setState(() => _requestedQuantities.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order submitted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place an Order')),
      body: StreamBuilder<List<StockItemModel>>(
        stream: _firestoreService.streamStockItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No stock items available yet.'));
          }

          final items = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('Available centrally: ${item.currentQty} ${item.unit}'),
                      trailing: SizedBox(
                        width: 100,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qty'),
                          onChanged: (value) {
                            _requestedQuantities[item.id] = double.tryParse(value) ?? 0;
                          },
                        ),
                      ),
                    );
                  },
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
      ),
    );
  }
}