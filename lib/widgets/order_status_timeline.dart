import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../utils/format.dart';

class _Step {
  final String label;
  final DateTime? at;
  final String? byName;
  final String? note;

  const _Step({required this.label, required this.at, this.byName, this.note});
}

/// Vertical stepper showing an order's full journey — requested, preparing,
/// delivered, received — with the timestamp (and actor, where recorded) for
/// each step already reached, so any role can see the whole history in one
/// place instead of just the slice their own screen tracks.
class OrderStatusTimeline extends StatelessWidget {
  final OrderModel order;

  const OrderStatusTimeline({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step(
        label: 'Requested',
        at: order.createdAt,
        byName: order.placedByName,
        note: order.note,
      ),
      _Step(
        label: 'Preparing',
        at: order.preparingAt,
        byName: order.preparedByName,
        note: order.preparingNote,
      ),
      _Step(
        label: 'Delivered',
        at: order.deliveredAt,
        byName: order.deliveredByName,
        note: order.deliveredNote,
      ),
      _Step(
        label: 'Received',
        at: order.receivedAt,
        byName: order.receivedByName,
        note: order.receivedNote,
      ),
    ];

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  steps[i].at != null
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: steps[i].at != null ? scheme.primary : scheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: steps[i].at != null ? null : scheme.outline,
                        ),
                      ),
                      if (steps[i].at != null)
                        Text(
                          steps[i].byName != null
                              ? '${formatTimestamp(steps[i].at!)} — by ${steps[i].byName}'
                              : formatTimestamp(steps[i].at!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (steps[i].note != null && steps[i].note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '"${steps[i].note}"',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
