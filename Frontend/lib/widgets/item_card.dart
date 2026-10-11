import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/text_format.dart';
import 'brand.dart';

/// AC 2.6.1 — name, quantity, days left, use-by date at a glance.
/// Storage location is shown as a coloured icon badge; urgency as a
/// coloured status pill (overdue items get a solid dark-red pill).
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, this.onTap});

  final FoodItem item;
  final VoidCallback? onTap;

  IconData get _storageIcon {
    switch (item.storageLocation) {
      case StorageLocation.fridge:
        return Icons.kitchen_outlined;
      case StorageLocation.freezer:
        return Icons.ac_unit;
      case StorageLocation.pantry:
        return Icons.inventory_2_outlined;
    }
  }

  /// Badge background per storage location.
  Color get _storageFill {
    switch (item.storageLocation) {
      case StorageLocation.fridge:
        return AppTheme.oceanLight;
      case StorageLocation.freezer:
        return const Color(0xFFE3EAF6);
      case StorageLocation.pantry:
        return AppTheme.honeyLight;
    }
  }

  /// Badge icon colour per storage location.
  Color get _storageIconColor {
    switch (item.storageLocation) {
      case StorageLocation.fridge:
        return AppTheme.ocean;
      case StorageLocation.freezer:
        return const Color(0xFF3D5A99);
      case StorageLocation.pantry:
        return AppTheme.honey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = item.daysLeft;
    final overdue = days < 0;
    final daysLabel = overdue
        ? '${-days}d overdue'
        : days == 0
            ? 'Due today'
            : '${days}d left';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 15),
          child: Row(
            children: [
              IconBadge(icon: _storageIcon, fill: _storageFill, iconColor: _storageIconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(capitaliseFirstLetter(item.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                            color: AppTheme.ink)),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatQty(item.quantity)} ${item.unit} · ${item.storageLocation.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.muted, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.muted, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                    if (item.isActive && item.consumedAmount != null) ...[
                      const SizedBox(height: 2),
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
                  StatusPill(
                    label: daysLabel,
                    color: overdue ? Colors.white : urgencyColor(days),
                    fill: urgencyFill(days),
                  ),
                  const SizedBox(height: 6),
                  Text(formatShortDate(item.useByDate),
                      style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}
