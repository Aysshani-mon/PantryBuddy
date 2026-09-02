import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../utils/date_format.dart';

/// AC 3.7.1 — shared "Recent Activity" feed, visible to all members.
class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recent activity')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final log = appState.activityLog;
          if (log.isEmpty) {
            return Center(
              child: Text('No activity yet.', style: TextStyle(color: Colors.grey.shade600)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: log.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final entry = log[i];
              return ListTile(
                leading: const Icon(Icons.circle, size: 8),
                title: Text(entry.message),
                subtitle: Text(formatRelativeTime(entry.timestamp)),
              );
            },
          );
        },
      ),
    );
  }
}
