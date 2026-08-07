import 'dart:convert';

import 'package:flutter/material.dart';

/// A fixed-size catalog item photo, or the same inventory-icon placeholder
/// everywhere an item has no photo yet — shared by the catalog and branch
/// order screens so the fallback stays consistent.
class StockItemThumbnail extends StatelessWidget {
  final String? imageBase64;
  final double size;

  const StockItemThumbnail({
    super.key,
    required this.imageBase64,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final data = imageBase64;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: data == null || data.isEmpty
            ? _placeholder(context)
            : Builder(
                builder: (context) {
                  try {
                    return Image.memory(
                      base64Decode(data),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _placeholder(context),
                    );
                  } catch (_) {
                    return _placeholder(context);
                  }
                },
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.inventory_2_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
