import '../models/order_model.dart';

String formatTimestamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// Every stock/order quantity is stored as a double (to allow fractional
/// units like kg), but whole-number amounts — the overwhelming majority —
/// shouldn't display as "10.0". Shows decimals only when the value actually
/// has a fractional part.
String formatQty(double qty) {
  return qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toString();
}

/// One line per order item, e.g. "Buns x10". Once an item has been
/// prepared with a different quantity than requested, shows both:
/// "Buns: requested 10, sent 7".
String orderItemsSummary(List<OrderItem> items) {
  return items
      .map((i) {
        final fulfilled = i.fulfilledQuantity;
        if (fulfilled != null && i.quantity == 0) {
          return '${i.name} x${formatQty(fulfilled)} (added)';
        }
        if (fulfilled != null && fulfilled != i.quantity) {
          return '${i.name}: requested ${formatQty(i.quantity)}, sent ${formatQty(fulfilled)}';
        }
        return '${i.name} x${formatQty(i.quantity)}';
      })
      .join(', ');
}
