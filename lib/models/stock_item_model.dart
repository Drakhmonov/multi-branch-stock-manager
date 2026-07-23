class StockItemModel {
  final String id;
  final String name;
  // Unit sold/ordered/logged in everywhere outside the catalog/restock layer
  // (e.g. "pcs", "litre", "bottle") — the smallest tracked unit.
  final String pieceUnit;
  // How the item is bought from the supplier (e.g. "bag", "20L can", "pack of 6").
  final String packLabel;
  // Pieces per pack; 1 for items not sold in packs.
  final double piecesPerPack;
  // Cost of one whole pack from the supplier.
  final double costPerPack;
  // Cost per piece — derived from costPerPack/piecesPerPack at write time;
  // this is what every ledger/report calculation actually uses.
  final double costPerUnit;
  // Central stock, always in pieceUnit.
  final double currentQty;
  final double reorderThreshold;
  final DateTime lastUpdated;

  StockItemModel({
    required this.id,
    required this.name,
    required this.pieceUnit,
    required this.packLabel,
    required this.piecesPerPack,
    required this.costPerPack,
    required this.costPerUnit,
    required this.currentQty,
    required this.reorderThreshold,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'pieceUnit': pieceUnit,
    'packLabel': packLabel,
    'piecesPerPack': piecesPerPack,
    'costPerPack': costPerPack,
    'costPerUnit': costPerUnit,
    'currentQty': currentQty,
    'reorderThreshold': reorderThreshold,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory StockItemModel.fromMap(String id, Map<String, dynamic> map) {
    final pieceUnit = map['pieceUnit'] ?? map['unit'] ?? '';
    return StockItemModel(
      id: id,
      name: map['name'] ?? '',
      pieceUnit: pieceUnit,
      packLabel: map['packLabel'] ?? pieceUnit,
      piecesPerPack: (map['piecesPerPack'] ?? 1).toDouble(),
      costPerPack: (map['costPerPack'] ?? map['costPerUnit'] ?? 0).toDouble(),
      costPerUnit: (map['costPerUnit'] ?? 0).toDouble(),
      currentQty: (map['currentQty'] ?? 0).toDouble(),
      reorderThreshold: (map['reorderThreshold'] ?? 0).toDouble(),
      lastUpdated: DateTime.parse(map['lastUpdated']),
    );
  }
}
