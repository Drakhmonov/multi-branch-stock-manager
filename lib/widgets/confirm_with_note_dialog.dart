import 'package:flutter/material.dart';

/// Simple confirm dialog with an optional note field, used for order-status
/// actions (mark delivered, confirm received) that don't need anything more
/// than "are you sure, and anything to add?". Returns the entered note
/// (possibly empty) on confirm, or `null` if the dialog was cancelled.
Future<String?> showConfirmWithNoteDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
}) {
  final noteController = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: noteController,
        decoration: const InputDecoration(labelText: 'Note (optional)'),
        maxLines: 2,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(noteController.text.trim()),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}
