import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'branch_order_screen.dart';
import 'receive_delivery_screen.dart';
import 'daily_stock_update_screen.dart';

class BranchHomeScreen extends StatelessWidget {
  final UserModel currentUser;

  const BranchHomeScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Branch — ${currentUser.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HomeTile(
            title: 'Place an Order',
            icon: Icons.add_shopping_cart,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BranchOrderScreen(currentUser: currentUser),
              ),
            ),
          ),
          _HomeTile(
            title: 'Receive Delivery',
            icon: Icons.local_shipping,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReceiveDeliveryScreen(currentUser: currentUser),
              ),
            ),
          ),
          _HomeTile(
            title: 'Daily Stock Update',
            icon: Icons.edit_note,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DailyStockUpdateScreen(currentUser: currentUser),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _HomeTile({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}