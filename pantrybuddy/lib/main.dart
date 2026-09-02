import 'dart:async';
import 'package:flutter/material.dart';

import 'data/api_data_store.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/create_profile_screen.dart';
import 'screens/onboarding/create_or_join_household_screen.dart';
import 'screens/onboarding/awaiting_approval_screen.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(PantryBuddyApp());
}

class PantryBuddyApp extends StatefulWidget {
  PantryBuddyApp({super.key});

  // Real backend (see the separate pantrybuddy-backend project and
  // lib/data/api_config.dart for the URL it points at). To go back to
  // the old no-backend mock for quick UI testing, swap this for
  // `InMemoryDataStore()` from data/mock_data_store.dart instead.
  final ApiDataStore dataStore = ApiDataStore();

  @override
  State<PantryBuddyApp> createState() => _PantryBuddyAppState();
}

class _PantryBuddyAppState extends State<PantryBuddyApp> {
  late final AppState _appState;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _appState = AppState(
      userRepo: widget.dataStore,
      householdRepo: widget.dataStore,
      inventoryRepo: widget.dataStore,
      reminderRepo: widget.dataStore,
      activityRepo: widget.dataStore,
      shelfLifeRepo: widget.dataStore,
    );
    // AC 3.2.1 — periodically checks for due reminders. A real deployment
    // would use a platform notification package (e.g. flutter_local_notifications)
    // to fire an actual push/local notification here; for iteration 1 this
    // surfaces a snackbar as a stand-in so the reminder flow is demoable.
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final due = await _appState.checkDueReminders();
      if (due.isNotEmpty && mounted) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('${due.length} item(s) nearing their expiry — check Reminders')),
        );
      }
    });
  }

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      title: 'PantryBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Paints the app's background gradient once, behind every screen —
      // works because ThemeData.scaffoldBackgroundColor and the AppBar
      // background are both set to transparent, so this shows through
      // everywhere without needing to touch each screen individually.
      builder: (context, child) {
        return DecoratedBox(
          decoration: const BoxDecoration(gradient: AppTheme.appBackgroundGradient),
          child: child,
        );
      },
      home: ListenableBuilder(
        listenable: _appState,
        builder: (context, _) {
          if (!_appState.hasProfile) {
            return CreateProfileScreen(appState: _appState);
          }
          if (_appState.isAwaitingApproval) {
            return AwaitingApprovalScreen(appState: _appState);
          }
          if (!_appState.hasHousehold) {
            return CreateOrJoinHouseholdScreen(appState: _appState);
          }
          return HomeScreen(appState: _appState);
        },
      ),
    );
  }
}
