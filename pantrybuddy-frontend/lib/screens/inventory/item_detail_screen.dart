import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../models/food_item.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import 'add_edit_item_screen.dart';

/// AC 2.6.1 plus item actions: consume / discard, edit, delete.
class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.appState, required this.item});
  final AppState appState;
  final FoodItem item;

  Future<void> _resolve(BuildContext context, ItemDisposition disposition) async {
    try {
      await appState.resolveItem(item, disposition);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t update this item: $e')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('This will remove "${item.name}" from your inventory.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await appState.removeItem(item);
        if (context.mounted) Navigator.of(context).pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t remove this item: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = urgencyColor(item.daysLeft);
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AddEditItemScreen(appState: appState, existingItem: item),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Quantity', '${item.quantity} ${item.unit}'),
                    _row('Storage location', item.storageLocation.label),
                    _row('Category', item.category.label),
                    _row('Use-by date', formatLongDate(item.useByDate)),
                    _row(
                      'Status',
                      item.daysLeft < 0 ? '${-item.daysLeft} days overdue' : '${item.daysLeft} days left',
                      valueColor: color,
                    ),
                  ],
                ),
              ),
            ),
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Note', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(item.notes!, style: const TextStyle(fontSize: 14.5)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (item.isActive) ...[
              const Text('What happened to this item?',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _resolve(context, ItemDisposition.consumed),
                  icon: const Icon(Icons.restaurant_outlined),
                  label: const Text('Consume'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _resolve(context, ItemDisposition.discarded),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Discard'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                ),
              ),
            ] else ...[
              Chip(label: Text('Marked as ${item.disposition!.name}')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}
