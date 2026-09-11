import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

/// AC 2.6.1 — name, quantity, days left, use-by date at a glance.
/// A left urgency-accent bar replaces the previous icon-chip-in-a-box
/// treatment — reads faster at a glance across a long list, and avoids
/// every card looking identical (the icon badge was decorative, not
/// informational, once the accent bar already carries urgency).
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, this.onTap});

  final FoodItem item;
  final VoidCallback? onTap;

  IconData get _storageIcon {
    switch (item.storageLocation) {
      case StorageLocation.fridge:
        return Icons.kitchen_outlined;
      case StorageLocation.freezer:
        return Icons.ac_unit_outlined;
      case StorageLocation.pantry:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = urgencyColor(item.daysLeft);
    final daysLabel = item.daysLeft < 0
        ? '${-item.daysLeft}d overdue'
        : item.daysLeft == 0
            ? 'Due today'
            : '${item.daysLeft}d left';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: AppTheme.ink)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(_storageIcon, size: 13, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  '${_formatQty(item.quantity)} ${item.unit} • ${item.storageLocation.label}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                                ),
                              ],
                            ),
                            if (item.notes != null && item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.notes!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ],
                            if (item.isActive && item.consumedAmount != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.consumedAmount!.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.honey, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(daysLabel,
                                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                          const SizedBox(height: 6),
                          Text(formatShortDate(item.useByDate),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}
