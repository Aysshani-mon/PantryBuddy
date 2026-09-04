import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/household.dart';
import '../models/join_request.dart';
import '../models/food_item.dart';
import '../models/reminder.dart';
import '../models/activity_log_entry.dart';
import '../models/shelf_life_suggestion.dart';
import '../data/repository.dart';
import '../services/id_service.dart';
import '../services/reminder_service.dart';

/// Single source of truth for "who am I / what household am I in / what's
/// in the inventory" — read via `AppState.of(context)` and rebuilt with
/// `ListenableBuilder` (core Flutter, no extra state-management package).
class AppState extends ChangeNotifier {
  AppState({
    required this.userRepo,
    required this.householdRepo,
    required this.inventoryRepo,
    required this.reminderRepo,
    required this.activityRepo,
    required this.shelfLifeRepo,
  });

  final UserRepository userRepo;
  final HouseholdRepository householdRepo;
  final InventoryRepository inventoryRepo;
  final ReminderRepository reminderRepo;
  final ActivityLogRepository activityRepo;
  final ShelfLifeRepository shelfLifeRepo;

  AppUser? currentUser;
  Household? currentHousehold;
  List<HouseholdMember> householdMembers = [];
  List<FoodItem> items = [];
  List<Reminder> reminders = [];
  List<ActivityLogEntry> activityLog = [];
  List<JoinRequest> pendingRequests = []; // visible to admins only

  /// Set while this user is waiting on a household admin to approve their
  /// join request (AC 3.5.1, revised) — null once approved/declined.
  JoinRequest? pendingMyJoinRequest;

  StreamSubscription<List<FoodItem>>? _itemsSub;
  StreamSubscription<List<ActivityLogEntry>>? _activitySub;
  StreamSubscription<JoinRequest>? _myJoinRequestSub;

  bool get hasProfile => currentUser != null;
  bool get hasHousehold => currentHousehold != null;
  bool get isAwaitingApproval => pendingMyJoinRequest != null;

  MembershipRole? get myRole {
    if (currentUser == null) return null;
    final mine = householdMembers.where((m) => m.user.id == currentUser!.id).firstOrNull;
    return mine?.role;
  }

  bool get isAdmin => myRole == MembershipRole.admin;

  // ---------------- Epic 1: Profile & household ----------------

  Future<void> signUp({
    required String name,
    required String avatarKey,
    required String email,
    required String password,
  }) async {
    currentUser = await userRepo.signUp(
      name: name,
      avatarKey: avatarKey,
      email: email,
      password: password,
    );
    notifyListeners();
  }

  /// Throws [AuthException] on failure — the sign-in screen catches this
  /// and shows the message inline.
  Future<void> signIn({required String email, required String password}) async {
    currentUser = await userRepo.signIn(email: email, password: password);

    final household = await householdRepo.getHouseholdForUser(currentUser!.id);
    if (household != null) {
      currentUser = currentUser!.copyWith(householdId: household.id);
      currentHousehold = household;
      _startWatching();
      notifyListeners();
      return;
    }

    // No active household — check whether they're still waiting on a
    // join request submitted before they last closed the app.
    final pending = await householdRepo.getMyPendingRequest(currentUser!.id);
    if (pending != null) {
      pendingMyJoinRequest = pending;
      _watchMyJoinRequest(pending);
    }
    notifyListeners();
  }

  Future<void> requestPasswordReset({required String email}) async {
    await userRepo.requestPasswordReset(email: email);
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    await userRepo.resetPassword(token: token, newPassword: newPassword);
  }

  Future<void> updateProfile({String? name, String? avatarKey}) async {
    if (currentUser == null) return;
    currentUser = currentUser!.copyWith(name: name, avatarKey: avatarKey);
    await userRepo.updateUser(currentUser!);
    _refreshMembers();
    notifyListeners();
  }

  Future<void> createHousehold({required String name}) async {
    if (currentUser == null) return;
    final household = await householdRepo.createHousehold(
      name: name,
      creatorUserId: currentUser!.id,
    );
    currentUser = currentUser!.copyWith(householdId: household.id);
    await userRepo.updateUser(currentUser!);
    currentHousehold = household;
    await _logJoin();
    _startWatching();
    notifyListeners();
  }

  /// AC 3.5.1 (revised) — submits a request to join; does NOT grant
  /// access yet. Throws [AuthException] on an invalid code or a
  /// duplicate pending request. Live-updates [pendingMyJoinRequest] via
  /// [watchJoinRequest] so the "waiting for approval" screen updates the
  /// moment an admin approves/declines it.
  Future<void> requestToJoinHousehold({required String inviteCode}) async {
    if (currentUser == null) return;
    final request = await householdRepo.requestToJoin(
      inviteCode: inviteCode,
      user: currentUser!,
    );
    pendingMyJoinRequest = request;
    notifyListeners();
    _watchMyJoinRequest(request);
  }

  /// Shared by [requestToJoinHousehold] and [signIn] (a returning user may
  /// still have a request pending from before they last closed the app).
  void _watchMyJoinRequest(JoinRequest request) {
    _myJoinRequestSub?.cancel();
    _myJoinRequestSub = householdRepo.watchJoinRequest(request.id).listen((updated) async {
      pendingMyJoinRequest = updated;
      if (updated.status == JoinRequestStatus.approved) {
        currentHousehold = await householdRepo.getHousehold(updated.householdId);
        currentUser = currentUser!.copyWith(householdId: updated.householdId);
        await userRepo.updateUser(currentUser!);
        _startWatching();
        pendingMyJoinRequest = null; // fully joined now — clear the pending marker
      }
      notifyListeners();
    });
  }

  /// Admin-only — see [isAdmin]. Refreshes [pendingRequests] and members.
  Future<void> approveJoinRequest(JoinRequest request) async {
    if (currentUser == null) return;
    await householdRepo.approveRequest(requestId: request.id, reviewedByUserId: currentUser!.id);
    await activityRepo.logActivity(ActivityLogEntry(
      id: IdService.newId('log'),
      householdId: request.householdId,
      actingUserId: currentUser!.id,
      actingUserName: currentUser!.name,
      action: ActivityAction.joined,
      itemName: request.userName,
    ));
    await _refreshPendingRequests();
    await _refreshMembers();
    notifyListeners();
  }

  Future<void> declineJoinRequest(JoinRequest request) async {
    if (currentUser == null) return;
    await householdRepo.declineRequest(requestId: request.id, reviewedByUserId: currentUser!.id);
    await _refreshPendingRequests();
    notifyListeners();
  }

  Future<void> _refreshPendingRequests() async {
    if (currentHousehold == null) return;
    pendingRequests = await householdRepo.getPendingRequests(currentHousehold!.id);
  }

  Future<void> _logJoin() async {
    if (currentUser == null || currentHousehold == null) return;
    await activityRepo.logActivity(ActivityLogEntry(
      id: IdService.newId('log'),
      householdId: currentHousehold!.id,
      actingUserId: currentUser!.id,
      actingUserName: currentUser!.name,
      action: ActivityAction.joined,
      itemName: '',
    ));
    await _refreshMembers();
  }

  Future<void> _refreshMembers() async {
    if (currentHousehold == null) return;
    householdMembers = await householdRepo.getMembers(currentHousehold!.id);
  }

  void _startWatching() {
    if (currentHousehold == null) return;
    _itemsSub?.cancel();
    _activitySub?.cancel();
    _itemsSub =
        inventoryRepo.watchItemsForHousehold(currentHousehold!.id).listen((list) {
      items = list;
      notifyListeners();
    });
    _activitySub = activityRepo
        .watchActivityForHousehold(currentHousehold!.id)
        .listen((list) {
      activityLog = list;
      notifyListeners();
    });
    reminderRepo.getRemindersForHousehold(currentHousehold!.id).then((list) {
      reminders = list;
      notifyListeners();
    });
    _refreshMembers().then((_) => notifyListeners());
    _refreshPendingRequests().then((_) => notifyListeners());
  }

  // ---------------- Epic 2: Inventory ----------------

  Future<FoodItem?> addItem({
    required String name,
    required double quantity,
    required String unit,
    required StorageLocation location,
    required ProductCategory category,
    required DateTime useByDate,
    String? notes,
  }) async {
    if (currentUser == null || currentHousehold == null) return null;
    final draft = FoodItem(
      id: IdService.newId('itm'), // placeholder — the backend assigns the real ID
      householdId: currentHousehold!.id,
      name: name,
      quantity: quantity,
      unit: unit,
      storageLocation: location,
      category: category,
      useByDate: useByDate,
      addedByUserId: currentUser!.id,
      notes: notes,
    );
    // IMPORTANT: use the item the backend actually created (real ID) —
    // not `draft`, whose id is just a local placeholder the server
    // ignores. Using `draft` here previously caused reminders attached
    // right after adding an item to silently fail (wrong/nonexistent
    // item id), which left the Add Item screen stuck on its loading
    // spinner since that error was never caught either.
    final created = await inventoryRepo.addItem(draft);
    await activityRepo.logActivity(ActivityLogEntry(
      id: IdService.newId('log'),
      householdId: currentHousehold!.id,
      actingUserId: currentUser!.id,
      actingUserName: currentUser!.name,
      action: ActivityAction.added,
      itemName: name,
    ));
    return created;
  }

  Future<void> updateItem(FoodItem item) async {
    if (currentUser == null || currentHousehold == null) return;
    await inventoryRepo.updateItem(item);
    await activityRepo.logActivity(ActivityLogEntry(
      id: IdService.newId('log'),
      householdId: currentHousehold!.id,
      actingUserId: currentUser!.id,
      actingUserName: currentUser!.name,
      action: ActivityAction.edited,
      itemName: item.name,
    ));
  }

  /// Consume / discard — resolves the item out of the active inventory.
  /// (A "donate" option was considered but dropped for now since the
  /// schema's status enum doesn't support it yet — see food_item.dart.)
  Future<void> resolveItem(FoodItem item, ItemDisposition disposition) async {
    if (currentUser == null || currentHousehold == null) return;
    item.disposition = disposition;
    item.resolvedAt = DateTime.now();
    await inventoryRepo.updateItem(item);
    await activityRepo.logActivity(ActivityLogEntry(
      id: IdService.newId('log'),
      householdId: currentHousehold!.id,
      actingUserId: currentUser!.id,
      actingUserName: currentUser!.name,
      action: ActivityAction.resolved,
      itemName: item.name,
    ));
  }

  Future<void> removeItem(FoodItem item) async {
    if (currentUser == null || currentHousehold == null) return;
    await inventoryRepo.removeItem(item.id);
    await activityRepo.logActivity(ActivityLogEntry(
      id: IdService.newId('log'),
      householdId: currentHousehold!.id,
      actingUserId: currentUser!.id,
      actingUserName: currentUser!.name,
      action: ActivityAction.removed,
      itemName: item.name,
    ));
  }

  List<FoodItem> get activeItems => items.where((i) => i.isActive).toList();

  List<FoodItem> itemsIn(StorageLocation location) =>
      activeItems.where((i) => i.storageLocation == location).toList();

  List<FoodItem> expiringWithin(int days) {
    final list = activeItems.where((i) => i.isExpiringWithin(days)).toList();
    list.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return list;
  }

  List<FoodItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return activeItems.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  // ---------------- Epic 3: Reminders ----------------

  Future<void> setReminder(FoodItem item, int leadTimeDays,
      {bool wasCustom = false}) async {
    if (currentHousehold == null || currentUser == null) return;
    if (!ReminderService.isValidLeadTime(
        leadTimeDays: leadTimeDays, useByDate: item.useByDate)) {
      throw ArgumentError('Lead time falls after the item\'s expiry date.');
    }
    final reminder = Reminder(
      id: IdService.newId('rem'),
      itemId: item.id,
      householdId: currentHousehold!.id,
      createdByUserId: currentUser!.id,
      leadTimeDays: leadTimeDays,
      wasCustomLeadTime: wasCustom,
    );
    await reminderRepo.setReminder(reminder);
    reminders = await reminderRepo.getRemindersForHousehold(currentHousehold!.id);
    notifyListeners();
  }

  /// AC 3.2.1 / AC 3.2.2 — called periodically (see main.dart's timer) to
  /// check which reminders are newly due and mark them triggered so they
  /// don't fire twice.
  Future<List<Reminder>> checkDueReminders() async {
    final due = <Reminder>[];
    for (final reminder in reminders) {
      if (reminder.triggered) continue;
      final item = items.where((i) => i.id == reminder.itemId).firstOrNull;
      if (item == null) continue;
      if (ReminderService.isDue(item: item, leadTimeDays: reminder.leadTimeDays)) {
        await reminderRepo.markTriggered(reminder.id);
        reminder.triggered = true;
        due.add(reminder);
      }
    }
    if (due.isNotEmpty) notifyListeners();
    return due;
  }

  List<Reminder> get sortedUpcomingReminders {
    final list = reminders.where((r) {
      final item = items.where((i) => i.id == r.itemId).firstOrNull;
      return item != null && item.isActive;
    }).toList();
    list.sort((a, b) {
      final itemA = items.firstWhere((i) => i.id == a.itemId);
      final itemB = items.firstWhere((i) => i.id == b.itemId);
      return (itemA.daysLeft - a.leadTimeDays)
          .compareTo(itemB.daysLeft - b.leadTimeDays);
    });
    return list;
  }

  // ==================== Shelf-life suggestions ====================

  /// See [ShelfLifeRepository.getSuggestion] — exposed here so screens
  /// only ever depend on AppState, not the repositories directly.
  Future<ShelfLifeSuggestion?> getShelfLifeSuggestion({
    required ProductCategory category,
    required StorageLocation location,
    String? itemName,
  }) {
    return shelfLifeRepo.getSuggestion(category: category, location: location, itemName: itemName);
  }

  Future<Map<StorageLocation, ShelfLifeSuggestion?>> getStorageSuggestions({
    required ProductCategory category,
    String? itemName,
  }) {
    return shelfLifeRepo.getStorageSuggestions(category: category, itemName: itemName);
  }

  // ==================== Sign out ====================

  /// Clears everything about the current session (token, profile,
  /// household, inventory, reminders, activity) and cancels all live
  /// subscriptions. main.dart's routing sends the user back to the
  /// sign-up/sign-in screen automatically once [currentUser] is null.
  Future<void> signOut() async {
    await userRepo.signOut();
    _itemsSub?.cancel();
    _activitySub?.cancel();
    _myJoinRequestSub?.cancel();
    _itemsSub = null;
    _activitySub = null;
    _myJoinRequestSub = null;

    currentUser = null;
    currentHousehold = null;
    householdMembers = [];
    items = [];
    reminders = [];
    activityLog = [];
    pendingRequests = [];
    pendingMyJoinRequest = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    _activitySub?.cancel();
    _myJoinRequestSub?.cancel();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
