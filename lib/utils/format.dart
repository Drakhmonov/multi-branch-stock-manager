import '../models/order_model.dart';

String formatTimestamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// One line per order item, e.g. "Buns x10". Once an item has been
/// prepared with a different quantity than requested, shows both:
/// "Buns: requested 10, sent 7".
String orderItemsSummary(List<OrderItem> items) {
  return items
      .map((i) {
        final fulfilled = i.fulfilledQuantity;
        if (fulfilled != null && i.quantity == 0) {
          return '${i.name} x$fulfilled (added)';
        }
        if (fulfilled != null && fulfilled != i.quantity) {
          return '${i.name}: requested ${i.quantity}, sent $fulfilled';
        }
        return '${i.name} x${i.quantity}';
      })
      .join(', ');
}
