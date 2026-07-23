import 'package:flutter/material.dart';
import '../models/branch_model.dart';
import '../services/firestore_service.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final _firestoreService = FirestoreService();
  late final Stream<List<BranchModel>> _branchesStream = _firestoreService
      .streamBranches();

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BranchModel>>(
      stream: _branchesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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

        final branches = snapshot.data!
          ..sort((a, b) => a.name.compareTo(b.name));

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final branch = branches[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.store),
                    title: Text(branch.name),
                    subtitle: Text(branch.location),
                  ),
                );
              },
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
