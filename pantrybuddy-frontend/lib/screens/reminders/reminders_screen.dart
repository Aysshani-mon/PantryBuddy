import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../models/reminder.dart';
import '../../theme/app_theme.dart';
import '../inventory/item_detail_screen.dart';
import '../../models/food_item.dart';

/// AC 3.3.1 — all upcoming reminders in one place, sorted by urgency.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          // Only show one reminder per item, even if multiple reminders exist for that item.
          final seenItemIds = <String>{};
          final reminders = appState.sortedUpcomingReminders.where((reminder) {
            final itemKey = '${reminder.householdId}:${reminder.itemId}';
            return seenItemIds.add(itemKey);
          }).toList();
          // Yola

          if (reminders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No reminders set yet. Add one from any item\'s page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reminders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _ReminderTile(appState: appState, reminder: reminders[i]),
          );
        },
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.appState, required this.reminder});
  final AppState appState;
  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final item = appState.items.where((i) => i.id == reminder.itemId).firstOrNull;
    if (item == null) return const SizedBox.shrink();
    // Added a storage location color label to the reminder card for better 
    // visibility of where the item is stored.
    final Color storageColor;
    final IconData storageIcon;

    switch (item.storageLocation) {
      case StorageLocation.fridge:
        storageColor = const Color(0xFF1565C0);
        storageIcon = Icons.kitchen_outlined;
        break;
      case StorageLocation.freezer:
        storageColor = const Color(0xFF00695C);
        storageIcon = Icons.ac_unit_outlined;
        break;
      case StorageLocation.pantry:
        storageColor = const Color(0xFF795548);
        storageIcon = Icons.inventory_2_outlined;
        break;
    }
    // Yola

    // Changed the visual representation of the reminder cards.
    // Added a color coding for the urgency of the reminder based on the
    // number of days left as follows:
    // 1. If item is more than 7 days from expiry date, the color is green. 
    // 2. If item is between 3-7 days from expiry date, the color is yellow. 
    // 3. If item is less than 3 days from expiry date, the color is red.
    // 4. If item is expired, the color is grey.
    final daysLeft = item.daysLeft;
    final Color cardColor;
    final Color textColor;

    if (daysLeft < 0) {
      cardColor = const Color(0xFFE0E0E0);
      textColor = Colors.black;
    } else if (daysLeft < 3) {
      cardColor = const Color(0xFFD50000);
      textColor = Colors.white;
    } else if (daysLeft < 7) {
      cardColor = const Color(0xFFFFEB3B);
      textColor = Colors.black;
    } else {
      cardColor = const Color(0xFF69F0AE);
      textColor = Colors.black;
    }

    final String expiryLabel;

    if (daysLeft < 0) {
  final overdueDays = -daysLeft;
  expiryLabel =
      'Expired $overdueDays day${overdueDays == 1 ? '' : 's'} ago';
    } else if (daysLeft == 0) {
      expiryLabel = 'Expires today';
    } else {
      expiryLabel = '$daysLeft day${daysLeft == 1 ? '' : 's'} until expiry';
    }

    return Card(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(
              appState: appState,
              item: item,
            ),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: textColor.withValues(alpha: 0.12),
          child: Icon(
            daysLeft < 0
                ? Icons.event_busy_outlined
                : Icons.notifications_active_outlined,
            color: textColor,
            size: 20,
          ),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),

            // White keeps the storage badge readable on every card colour.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: storageColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    storageIcon,
                    size: 14,
                    color: storageColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.storageLocation.label,
                    style: TextStyle(
                      color: storageColor,
                      fontSize: 12,
                  fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Text(
              'Reminds ${reminder.leadTimeDays} '
              'day${reminder.leadTimeDays == 1 ? '' : 's'} before',
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              expiryLabel,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (daysLeft < 0) ...[
              const SizedBox(height: 4),
              Text(
                'Open item to record disposal',
                style: TextStyle(color: textColor),
              ),
            ],
          ],
        ),
        trailing: reminder.triggered
            ? Icon(
                Icons.notifications,
                color: textColor,
                size: 20,
              )
            : null,
      ),
    );
    // Yola

  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
