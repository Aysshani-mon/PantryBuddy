import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/household.dart';
import '../models/join_request.dart';
import '../models/food_item.dart';
import '../models/reminder.dart';
import '../models/activity_log_entry.dart';
import '../models/shelf_life_suggestion.dart';
import 'api_config.dart';
import 'repository.dart';

/// Talks to the real pantrybuddy-backend API instead of holding data in
/// memory. See lib/data/README.md for the full model<->schema mapping and
/// lib/data/api_config.dart for how to point this at your running backend.
///
/// The backend has no websocket/SSE support, so the `watch*` streams here
/// are implemented as simple polling loops (every few seconds) rather than
/// true push updates — good enough for a small household app, and the
/// public API (a Stream) is unchanged from the mock, so nothing upstream
/// needed to change.
class ApiDataStore
    implements
        UserRepository,
        HouseholdRepository,
        InventoryRepository,
        ReminderRepository,
        ActivityLogRepository,
        ShelfLifeRepository {
  ApiDataStore({this.baseUrl = ApiConfig.baseUrl});

  final String baseUrl;

  /// The JWT issued at sign-up/sign-in, attached to every request after
  /// that. Held only in memory — cleared on [signOut] or app restart (the
  /// user simply signs in again; see main.dart's routing).
  String? _token;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Sends the request, decodes JSON, and throws [AuthException] with the
  /// server's message on any non-2xx response (the sign-up/sign-in/join
  /// screens already catch AuthException and display .message). A hard
  /// timeout means a stuck connection surfaces as an error within 20s
  /// instead of leaving the UI spinning forever with no explanation.
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    late http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw AuthException(
          'The server took too long to respond. Check your connection and that the backend is running, then try again.');
    } catch (e) {
      throw AuthException('Couldn\'t reach the server at $baseUrl — is the backend running? ($e)');
    }
    if (response.statusCode == 204 || response.body.isEmpty) {
      return response.statusCode >= 200 && response.statusCode < 300 ? null : _throwFor(response);
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      // The platform (Vercel, a proxy, etc.) can occasionally return a
      // plain HTML/text error page instead of JSON — e.g. a gateway
      // timeout or routing error. Without this, that used to throw an
      // uncaught FormatException here that nothing downstream caught,
      // leaving the UI stuck on its loading spinner forever.
      throw AuthException(
          'Unexpected response from the server (HTTP ${response.statusCode}). Please try again in a moment.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded is Map && decoded['error'] is String) ? decoded['error'] as String : 'Request failed (${response.statusCode}).';
      throw AuthException(message);
    }
    return decoded;
  }

  Never _throwFor(http.Response response) {
    throw AuthException('Request failed (${response.statusCode}).');
  }

  Future<dynamic> _get(String path) => _send(() => http.get(_uri(path), headers: _jsonHeaders));
  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) =>
      _send(() => http.post(_uri(path), headers: _jsonHeaders, body: body == null ? null : jsonEncode(body)));
  Future<dynamic> _put(String path, Map<String, dynamic> body) =>
      _send(() => http.put(_uri(path), headers: _jsonHeaders, body: jsonEncode(body)));
  Future<dynamic> _patch(String path, Map<String, dynamic> body) =>
      _send(() => http.patch(_uri(path), headers: _jsonHeaders, body: jsonEncode(body)));
  Future<dynamic> _delete(String path) => _send(() => http.delete(_uri(path), headers: _jsonHeaders));

  String _dateOnly(DateTime d) => d.toIso8601String().split('T').first;

  /// Polls [fetch] immediately and then every [interval] — see the class
  /// doc for why (no websockets on the backend yet).
  Stream<T> _pollStream<T>(Future<T> Function() fetch, {Duration interval = const Duration(seconds: 4)}) async* {
    while (true) {
      yield await fetch();
      await Future.delayed(interval);
    }
  }

  // ==================== Parsing helpers ====================

  AppUser _userFromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        avatarKey: json['avatarKey'] as String,
      );

  Household _householdFromJson(Map<String, dynamic> json) => Household(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  HouseholdMember _memberFromJson(Map<String, dynamic> json) => HouseholdMember(
        user: _userFromJson(json['user'] as Map<String, dynamic>),
        role: json['role'] == 'admin' ? MembershipRole.admin : MembershipRole.member,
        status: json['status'] == 'active' ? MembershipStatus.active : MembershipStatus.inactive,
      );

  JoinRequest _joinRequestFromJson(Map<String, dynamic> json) => JoinRequest(
        id: json['id'] as String,
        householdId: json['householdId'] as String,
        householdName: json['householdName'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String,
        userAvatarKey: json['userAvatarKey'] as String,
        status: JoinRequestStatus.values.byName(json['status'] as String),
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        reviewedAt: json['reviewedAt'] == null ? null : DateTime.parse(json['reviewedAt'] as String),
        reviewedByUserId: json['reviewedByUserId'] as String?,
      );

  FoodItem _itemFromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        householdId: json['householdId'] as String,
        name: json['name'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String,
        storageLocation: StorageLocation.values.byName(json['storageLocation'] as String),
        category: ProductCategory.values.byName(json['category'] as String),
        useByDate: DateTime.parse(json['useByDate'] as String),
        addedByUserId: json['addedByUserId'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
        disposition: json['disposition'] == null
            ? null
            : ItemDisposition.values.byName(json['disposition'] as String),
        resolvedAt: json['resolvedAt'] == null ? null : DateTime.parse(json['resolvedAt'] as String),
      );

  Reminder _reminderFromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        itemId: json['itemId'] as String,
        householdId: json['householdId'] as String,
        createdByUserId: json['createdByUserId'] as String? ?? '',
        leadTimeDays: json['leadTimeDays'] as int,
        wasCustomLeadTime: json['wasCustomLeadTime'] as bool? ?? false,
        triggered: json['triggered'] as bool? ?? false,
        triggeredAt: json['triggeredAt'] == null ? null : DateTime.parse(json['triggeredAt'] as String),
      );

  ActivityLogEntry _activityFromJson(Map<String, dynamic> json) => ActivityLogEntry(
        id: json['id'] as String,
        householdId: json['householdId'] as String,
        actingUserId: json['actingUserId'] as String,
        actingUserName: json['actingUserName'] as String,
        action: ActivityAction.values.byName(json['action'] as String),
        itemName: json['itemName'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  // ==================== UserRepository ====================

  @override
  Future<AppUser> signUp({
    required String name,
    required String avatarKey,
    required String email,
    required String password,
  }) async {
    final json = await _post('/auth/signup', {
      'name': name,
      'email': email,
      'password': password,
      'avatarKey': avatarKey,
    }) as Map<String, dynamic>;
    _token = json['token'] as String?;
    return _userFromJson(json);
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    final json = await _post('/auth/signin', {'email': email, 'password': password}) as Map<String, dynamic>;
    _token = json['token'] as String?;
    return _userFromJson(json);
  }

  @override
  Future<void> signOut() async {
    _token = null;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _post('/auth/forgot-password', {'email': email});
  }

  @override
  Future<AppUser?> getUser(String userId) async {
    try {
      final json = await _get('/users/$userId');
      return _userFromJson(json as Map<String, dynamic>);
    } on AuthException {
      return null;
    }
  }

  @override
  Future<AppUser> updateUser(AppUser user) async {
    final json = await _patch('/users/${user.id}', {'name': user.name, 'avatarKey': user.avatarKey});
    return _userFromJson(json as Map<String, dynamic>);
  }

  // ==================== HouseholdRepository ====================

  @override
  Future<Household> createHousehold({required String name, required String creatorUserId}) async {
    final json = await _post('/households', {'name': name, 'creatorUserId': creatorUserId});
    return _householdFromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Household?> getHousehold(String householdId) async {
    try {
      final json = await _get('/households/$householdId');
      return _householdFromJson(json as Map<String, dynamic>);
    } on AuthException {
      return null;
    }
  }

  @override
  Future<Household?> findByInviteCode(String inviteCode) async {
    try {
      final json = await _get('/households/by-invite/$inviteCode');
      if (json == null) return null;
      return _householdFromJson(json as Map<String, dynamic>);
    } on AuthException {
      return null;
    }
  }

  @override
  Future<List<HouseholdMember>> getMembers(String householdId) async {
    final json = await _get('/households/$householdId/members');
    return (json as List).map((e) => _memberFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Household?> getHouseholdForUser(String userId) async {
    final json = await _get('/users/$userId/households');
    final list = (json as List).map((e) => _householdFromJson(e as Map<String, dynamic>)).toList();
    return list.isEmpty ? null : list.first;
  }

  @override
  Future<JoinRequest?> getMyPendingRequest(String userId) async {
    final json = await _get('/users/$userId/join-requests?status=pending');
    final list = (json as List).map((e) => _joinRequestFromJson(e as Map<String, dynamic>)).toList();
    return list.isEmpty ? null : list.first;
  }

  @override
  Future<JoinRequest> requestToJoin({required String inviteCode, required AppUser user}) async {
    final json = await _post('/join-requests', {'inviteCode': inviteCode, 'userId': user.id});
    return _joinRequestFromJson(json as Map<String, dynamic>);
  }

  @override
  Future<List<JoinRequest>> getPendingRequests(String householdId) async {
    final json = await _get('/households/$householdId/join-requests?status=pending');
    return (json as List).map((e) => _joinRequestFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Stream<JoinRequest> watchJoinRequest(String requestId) {
    return _pollStream(() async {
      final json = await _get('/join-requests/$requestId');
      return _joinRequestFromJson(json as Map<String, dynamic>);
    });
  }

  @override
  Future<void> approveRequest({required String requestId, required String reviewedByUserId}) async {
    await _post('/join-requests/$requestId/approve', {'reviewedByUserId': reviewedByUserId});
  }

  @override
  Future<void> declineRequest({required String requestId, required String reviewedByUserId}) async {
    await _post('/join-requests/$requestId/decline', {'reviewedByUserId': reviewedByUserId});
  }

  // ==================== InventoryRepository ====================

  @override
  Future<FoodItem> addItem(FoodItem item) async {
    final json = await _post('/households/${item.householdId}/inventory-items', {
      'name': item.name,
      'quantity': item.quantity,
      'storageLocation': item.storageLocation.name,
      'category': item.category.name,
      'useByDate': _dateOnly(item.useByDate),
      'addedByUserId': item.addedByUserId,
    });
    return _itemFromJson(json as Map<String, dynamic>);
  }

  @override
  Future<FoodItem> updateItem(FoodItem item) async {
    if (item.disposition != null) {
      // Resolving (consume/discard) goes through the dedicated endpoint
      // so the backend can also record the inventory_transactions row.
      final json = await _post('/inventory-items/${item.id}/resolve', {
        'disposition': item.disposition!.name,
        'resolvedByUserId': item.addedByUserId,
      });
      return _itemFromJson(json as Map<String, dynamic>);
    }
    final json = await _put('/inventory-items/${item.id}', {
      'name': item.name,
      'quantity': item.quantity,
      'storageLocation': item.storageLocation.name,
      'category': item.category.name,
      'useByDate': _dateOnly(item.useByDate),
    });
    return _itemFromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> removeItem(String itemId) async {
    await _delete('/inventory-items/$itemId');
  }

  @override
  Future<List<FoodItem>> getItemsForHousehold(String householdId) async {
    final json = await _get('/households/$householdId/inventory-items');
    return (json as List).map((e) => _itemFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<FoodItem>> watchItemsForHousehold(String householdId) {
    return _pollStream(() => getItemsForHousehold(householdId));
  }

  // ==================== ReminderRepository ====================

  @override
  Future<Reminder> setReminder(Reminder reminder) async {
    final json = await _post('/reminders', {
      'itemId': reminder.itemId,
      'householdId': reminder.householdId,
      'leadTimeDays': reminder.leadTimeDays,
      'createdByUserId': reminder.createdByUserId,
    });
    return _reminderFromJson(json as Map<String, dynamic>);
  }

  @override
  Future<List<Reminder>> getRemindersForHousehold(String householdId) async {
    final json = await _get('/households/$householdId/reminders');
    return (json as List).map((e) => _reminderFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> markTriggered(String reminderId) async {
    await _post('/reminders/$reminderId/mark-triggered');
  }

  // ==================== ActivityLogRepository ====================

  @override
  Future<void> logActivity(ActivityLogEntry entry) async {
    // No-op: the backend derives the activity feed from
    // inventory_transactions + team_members.joined_at automatically
    // (there's no separate activity-log table in the schema) — see
    // lib/data/README.md "Known gaps" and src/routes/activity.js.
  }

  @override
  Future<List<ActivityLogEntry>> getActivityForHousehold(String householdId) async {
    final json = await _get('/households/$householdId/activity');
    return (json as List).map((e) => _activityFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<ActivityLogEntry>> watchActivityForHousehold(String householdId) {
    return _pollStream(() => getActivityForHousehold(householdId));
  }

  // ==================== ShelfLifeRepository ====================

  @override
  Future<ShelfLifeSuggestion?> getSuggestion({
    required ProductCategory category,
    required StorageLocation location,
    String? itemName,
  }) async {
    final params = {
      'category': category.name,
      'storageLocation': location.name,
      if (itemName != null && itemName.trim().isNotEmpty) 'itemName': itemName.trim(),
    };
    final query = Uri(queryParameters: params).query;
    final json = await _get('/shelf-life-suggestion?$query');
    if (json == null) return null;
    return ShelfLifeSuggestion.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Map<StorageLocation, ShelfLifeSuggestion?>> getStorageSuggestions({
    required ProductCategory category,
    String? itemName,
  }) async {
    final params = {
      'category': category.name,
      if (itemName != null && itemName.trim().isNotEmpty) 'itemName': itemName.trim(),
    };
    final query = Uri(queryParameters: params).query;
    final json = await _get('/storage-suggestions?$query') as Map<String, dynamic>;
    return {
      for (final location in StorageLocation.values)
        location: json[location.name] == null
            ? null
            : ShelfLifeSuggestion.fromJson(json[location.name] as Map<String, dynamic>),
    };
  }
}
