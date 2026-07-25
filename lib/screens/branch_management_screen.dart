import 'package:flutter/material.dart';
import '../models/branch_model.dart';
import '../services/firestore_service.dart';
import '../widgets/stream_error_view.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final _firestoreService = FirestoreService();
  late final Stream<List<BranchModel>> _branchesStream = _firestoreService
      .streamBranches();
  final Set<String> _processingIds = {};

  Future<void> _showAddBranchDialog() async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final name = nameController.text.trim();
              final location = locationController.text.trim();
              if (name.isEmpty || location.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Enter both a name and a location.'),
                  ),
                );
                return;
              }

              setDialogState(() => isSubmitting = true);
              try {
                await _firestoreService.addBranch(
                  name: name,
                  location: location,
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() => isSubmitting = false);
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to add branch: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Add Branch'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleArchive(BranchModel branch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive branch?'),
        content: Text(
          '"${branch.name}" will no longer appear for new sign-ups, but all '
          "its existing orders, stock, and reports stay exactly as they are. "
          'You can reactivate it any time from the Archived list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingIds.add(branch.id));
    try {
      await _firestoreService.archiveBranch(branch.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to archive: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(branch.id));
    }
  }

  Future<void> _handleReactivate(BranchModel branch) async {
    setState(() => _processingIds.add(branch.id));
    try {
      await _firestoreService.reactivateBranch(branch.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to reactivate: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(branch.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BranchModel>>(
      stream: _branchesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return StreamErrorView(error: snapshot.error);
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Stack(
            children: [
              const Center(
                child: Text('No branches yet. Add one to get started.'),
              ),
              _buildFab(),
            ],
          );
        }

        final branches = List.of(snapshot.data!)
          ..sort((a, b) => a.name.compareTo(b.name));
        final active = branches.where((b) => b.active).toList();
        final archived = branches.where((b) => !b.active).toList();

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              children: [
                Text(
                  'Active (${active.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (active.isEmpty) const Text('No active branches.'),
                ...active.map(
                  (branch) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.store),
                      title: Text(branch.name),
                      subtitle: Text(branch.location),
                      trailing: _processingIds.contains(branch.id)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : TextButton(
                              onPressed: () => _handleArchive(branch),
                              child: const Text('Archive'),
                            ),
                    ),
                  ),
                ),
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Archived (${archived.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...archived.map(
                    (branch) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          Icons.store,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        title: Text(branch.name),
                        subtitle: Text(branch.location),
                        trailing: _processingIds.contains(branch.id)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton(
                                onPressed: () => _handleReactivate(branch),
                                child: const Text('Reactivate'),
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            _buildFab(),
          ],
        );
      },
    );
  }

  Widget _buildFab() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton(
        onPressed: _showAddBranchDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
