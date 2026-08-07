import '../models/order_model.dart';
import '../models/stock_item_model.dart';

String formatTimestamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// A branch's requested delivery date, shown relative to today since that's
/// the distinction that actually matters day-to-day ("do we need this out
/// this afternoon or is tomorrow fine") rather than a bare calendar date.
String formatRequestedDate(DateTime d) {
  final today = DateTime.now();
  final difference = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// Every stock/order quantity is stored as a double (to allow fractional
/// units like kg), but whole-number amounts — the overwhelming majority —
/// shouldn't display as "10.0". Shows decimals only when the value actually
/// has a fractional part.
String formatQty(double qty) {
  return qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toString();
}

/// Formats a piece quantity for display, converting to packs when the
/// catalog item is packaged — e.g. "2 bags (40 pcs)" rather than the raw
/// piece count everywhere orders show a quantity. Falls back to a bare piece
/// count if the item isn't in [catalog] (e.g. it's since been deleted).
String formatItemQty(double pieces, StockItemModel? stockItem) {
  if (stockItem == null || stockItem.piecesPerPack <= 1) {
    final unit = stockItem?.pieceUnit;
    return unit != null && unit.isNotEmpty
        ? '${formatQty(pieces)} $unit'
        : formatQty(pieces);
  }
  final packs = pieces / stockItem.piecesPerPack;
  final packsLabel = packs == packs.roundToDouble()
      ? packs.toStringAsFixed(0)
      : packs.toStringAsFixed(1);
  final plural = packs == 1 ? '' : 's';
  return '$packsLabel ${stockItem.packLabel}$plural '
      '(${formatQty(pieces)} ${stockItem.pieceUnit})';
}

/// One line per order item, e.g. "Buns x10 pcs" or, for a packaged item,
/// "Dumplings x2 bags (40 pcs)". Once an item has been prepared with a
/// different quantity than requested, shows both: "Buns: requested 10 pcs,
/// sent 7 pcs". [catalog] maps stockItemId to the current catalog entry, used
/// to resolve pack composition — order items themselves only ever store a
/// raw piece quantity, per the Phase 13 design.
String orderItemsSummary(
  List<OrderItem> items,
  Map<String, StockItemModel> catalog,
) {
  return items
      .map((i) {
        final stockItem = catalog[i.stockItemId];
        final fulfilled = i.fulfilledQuantity;
        if (fulfilled != null && i.quantity == 0) {
          return '${i.name} x${formatItemQty(fulfilled, stockItem)} (added)';
        }
        if (fulfilled != null && fulfilled != i.quantity) {
          return '${i.name}: requested ${formatItemQty(i.quantity, stockItem)}, '
              'sent ${formatItemQty(fulfilled, stockItem)}';
        }
        return '${i.name} x${formatItemQty(i.quantity, stockItem)}';
      })
      .join(', ');
}
