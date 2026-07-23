import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/adaptive_nav_shell.dart';
import 'branch_order_screen.dart';
import 'receive_delivery_screen.dart';
import 'daily_stock_update_screen.dart';
import 'branch_history_screen.dart';

class BranchHomeScreen extends StatelessWidget {
  final UserModel currentUser;
  final VoidCallback onSignOut;

  const BranchHomeScreen({
    super.key,
    required this.currentUser,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, String>>(
      stream: FirestoreService().streamBranchNames(),
      builder: (context, branchSnapshot) {
        final branchName =
            branchSnapshot.data?[currentUser.branchId] ?? 'Branch';

        return AdaptiveNavShell(
          subtitle: '$branchName — ${currentUser.name}',
          onSignOut: () async {
            await AuthService().signOut();
            onSignOut();
          },
          destinations: [
            NavDestination(
              label: 'Order',
              icon: Icons.add_shopping_cart,
              contentBuilder: (_) =>
                  BranchOrderScreen(currentUser: currentUser),
            ),
            NavDestination(
              label: 'Orders',
              icon: Icons.local_shipping,
              contentBuilder: (_) =>
                  ReceiveDeliveryScreen(currentUser: currentUser),
            ),
            NavDestination(
              label: 'Daily Update',
              icon: Icons.edit_note,
              contentBuilder: (_) =>
                  DailyStockUpdateScreen(currentUser: currentUser),
            ),
            NavDestination(
              label: 'History',
              icon: Icons.history,
              contentBuilder: (_) =>
                  BranchHistoryScreen(currentUser: currentUser),
            ),
          ],
        );
      },
    );
  }
}
