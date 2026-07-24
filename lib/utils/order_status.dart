import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../theme/app_theme.dart';

String orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.requested:
      return 'Requested';
    case OrderStatus.preparing:
      return 'Preparing';
    case OrderStatus.prepared:
      return 'Prepared';
    case OrderStatus.delivered:
      return 'Delivered';
    case OrderStatus.received:
      return 'Received';
    case OrderStatus.cancelled:
      return 'Cancelled';
  }
}

/// Same status-to-tint mapping used everywhere an order list shows more than
/// one status at once (manager's Orders tab, kitchen's history) — `null`
/// means "leave the card at the default surface color."
Color? orderStatusColor(BuildContext context, OrderStatus status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case OrderStatus.preparing:
      return scheme.tertiaryContainer;
    case OrderStatus.prepared:
      return scheme.primaryContainer;
    case OrderStatus.delivered:
      return scheme.secondaryContainer;
    case OrderStatus.received:
      return Theme.of(context).extension<StatusColors>()!.successContainer;
    case OrderStatus.requested:
    case OrderStatus.cancelled:
      return null;
  }
}
