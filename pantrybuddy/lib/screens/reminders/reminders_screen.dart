import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../models/reminder.dart';
import '../../theme/app_theme.dart';
import '../inventory/item_detail_screen.dart';

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
          final reminders = appState.sortedUpcomingReminders;
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
    final color = urgencyColor(item.daysLeft);

    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ItemDetailScreen(appState: appState, item: item),
        )),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.notifications_active_outlined, color: color, size: 20),
        ),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Reminds ${reminder.leadTimeDays} day${reminder.leadTimeDays == 1 ? '' : 's'} before • '
          '${item.daysLeft} days left',
        ),
        trailing: reminder.triggered
            ? const Icon(Icons.notifications, color: Colors.orange, size: 20)
            : null,
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
