import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../state/app_state.dart';
import '../../models/app_user.dart';
import '../../models/food_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/item_card.dart';
import '../../widgets/brand.dart';
import '../inventory/expiring_soon_screen.dart';
import '../inventory/item_detail_screen.dart';
import '../household/switch_household_screen.dart';
import '../recipes/recipe_suggestions_screen.dart';
import '../inventory/add_edit_item_screen.dart';

const _expiringSoonWindowDays = 3;

/// AC 1.2.2 — household name + user avatar in the header (forest hero).
/// AC 2.2.1 — total count + per-category breakdown.
/// AC 2.3.1 / AC 2.4.1 — expiring soon preview + "View All".
/// (Split into "Expiring soon" and "Expired" sections.)
/// AC 2.7.1 — search across all locations.
class HomeOverviewTab extends StatefulWidget {
  const HomeOverviewTab({
    super.key,
    required this.appState,
    required this.onViewInventory,
    // Added an onViewStorage field in constructor.
    required this.onViewStorage,
    // Yola
  });

  final AppState appState;
  final VoidCallback onViewInventory;
  // Added an onViewStorage field in constructor.
  final ValueChanged<StorageLocation> onViewStorage;
  // Yola

  @override
  State<HomeOverviewTab> createState() => _HomeOverviewTabState();
}

class _HomeOverviewTabState extends State<HomeOverviewTab> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounced so the list only re-filters/rebuilds ~300ms after typing
  /// pauses, instead of on every single keystroke — typing fast in
  /// search was a real, noticeable source of lag.
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No SafeArea: the forest hero runs under the status bar and pads
      // itself (see _buildHero).
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final state = widget.appState;
          final searchQuery = _searchController.text;
          final searchResults =
              searchQuery.trim().isEmpty ? null : state.search(searchQuery);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHero(context, state)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _buildSearchBar(),
                ),
              ),
              if (searchResults != null)
                _buildSearchResults(context, searchResults)
              else ...[
                SliverToBoxAdapter(child: _buildExpiringSoon(context, state)),
                SliverToBoxAdapter(child: _buildRecipeIdeas(context, state)),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ],
          );
        },
      ),
    );
  }

  String _greeting(AppUser? user) {
    final hour = DateTime.now().hour;
    final part = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final first = user?.name.trim().split(RegExp(r'\s+')).first ?? '';
    return first.isEmpty ? part : '$part, $first';
  }

  /// Forest-green hero: household switcher, greeting, item counts per
  /// storage location (tap to open that location in Inventory — Yola's
  /// navigation), and the Add Item action.
  Widget _buildHero(BuildContext context, AppState state) {
    final user = state.currentUser;
    final active = state.activeItems;
    final expiringSoonCount = active
        .where((i) => i.daysLeft >= 0 && i.daysLeft <= _expiringSoonWindowDays)
        .length;
    final byLocation = {
      for (final loc in StorageLocation.values)
        loc: active.where((i) => i.storageLocation == loc).length,
    };
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, top + 14, 20, 22),
        decoration: const BoxDecoration(
          color: AppTheme.forest,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHouseholdSwitcher(context, state),
            const SizedBox(height: 18),
            Text(
              _greeting(user),
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w600,
                fontSize: 27,
                height: 1.15,
                letterSpacing: -0.3,
                color: AppTheme.onForest,
              ),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${active.length} ${active.length == 1 ? 'item' : 'items'}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' in your inventory'),
                  if (expiringSoonCount > 0) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: '$expiringSoonCount',
                      style: const TextStyle(color: AppTheme.saffron, fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' expiring soon'),
                  ],
                ],
              ),
              style: const TextStyle(color: AppTheme.onForestMuted, fontSize: 14.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < StorageLocation.values.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _buildStorageTile(
                      StorageLocation.values[i],
                      byLocation[StorageLocation.values[i]] ?? 0,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // Add Item replaces the old View Inventory button (team
                // decision) — opens the Add Item screen directly.
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.saffron,
                  foregroundColor: AppTheme.ink,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddEditItemScreen(appState: widget.appState)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tappable — opens the household switcher.
  Widget _buildHouseholdSwitcher(BuildContext context, AppState state) {
    final user = state.currentUser;
    final household = state.currentHousehold;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SwitchHouseholdScreen(appState: state),
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.onForest,
                child: Text(
                  user != null ? AvatarCatalog.emojiFor(user.avatarKey) : '🥕',
                  style: const TextStyle(fontSize: 21),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOUSEHOLD', style: AppTheme.kicker.copyWith(color: AppTheme.onForestKicker)),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            household?.name ?? 'Your household',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.onForest,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more, color: AppTheme.onForest, size: 22),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One storage location on the hero — opens that location's tab in
  /// Inventory (Yola).
  Widget _buildStorageTile(StorageLocation location, int count) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onViewStorage(location),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
          child: Column(
            children: [
              SizedBox(height: 50, child: FittedBox(child: _buildStorageIllustration(location))),
              const SizedBox(height: 6),
              Text(
                location.label,
                style: const TextStyle(color: AppTheme.onForestMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: AppTheme.statNumberStyle.copyWith(fontSize: 26, color: AppTheme.onForest),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => _onSearchChanged(),
      decoration: InputDecoration(
        hintText: 'Search your inventory',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _searchController.clear()),
              ),
      ),
    );
  }

  /// Small illustrations for the three storage locations — kept exactly
  /// as designed, only the surrounding hero card's background color
  /// changed (not these).
  Widget _buildStorageIllustration(StorageLocation location) {
    final isPantry = location == StorageLocation.pantry;
    final isFreezer = location == StorageLocation.freezer;

    final outline = isPantry ? const Color(0xFF795548) : const Color(0xFF356477);
    final fill = isPantry ? const Color(0xFFFFE0B2) : const Color(0xFFDCEFF5);

    Widget handle() {
      return Container(
        width: 4,
        height: 12,
        decoration: BoxDecoration(color: outline, borderRadius: BorderRadius.circular(2)),
      );
    }

    Widget jar(Color color) {
      return Container(
        width: 12,
        height: 17,
        decoration: BoxDecoration(
          color: color,
          border: Border(top: BorderSide(color: outline, width: 4)),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    return SizedBox(
      height: 80,
      child: Center(
        child: Container(
          width: isFreezer ? 76 : 56,
          height: isFreezer ? 52 : 76,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: outline, width: 2),
            borderRadius: BorderRadius.circular(7),
          ),
          child: isPantry
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [jar(const Color(0xFF81A969)), jar(const Color(0xFFD99562))],
                    ),
                    Divider(color: outline, thickness: 2, height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [jar(const Color(0xFFD6AD52)), jar(const Color(0xFF81A969))],
                    ),
                  ],
                )
              : isFreezer
                  ? Column(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: outline, width: 2))),
                          alignment: Alignment.center,
                          child: Container(width: 18, height: 3, color: outline),
                        ),
                        Expanded(child: Icon(Icons.ac_unit, color: outline, size: 24)),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 25,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(padding: const EdgeInsets.only(left: 7), child: handle()),
                          ),
                        ),
                        Divider(color: outline, thickness: 2, height: 2),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(padding: const EdgeInsets.only(left: 7), child: handle()),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildExpiringSoon(BuildContext context, AppState state) {
    // Split into "Expiring soon" and "Expired" so expired food is clearly
    // separated from food that still needs using up (Yola).
    final activeItems = state.activeItems;

    final expiringSoon = activeItems.where((item) {
      final days = item.daysLeft;
      return days >= 0 && days <= _expiringSoonWindowDays;
    }).toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    final expired = activeItems
        .where((item) => item.daysLeft < 0)
        .toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExpirySection(
            context,
            title: 'Expiring soon',
            description: 'Expires today or within $_expiringSoonWindowDays days.',
            items: expiringSoon,
            expiredOnly: false,
            emptyMessage: 'Nothing nearing expiry.',
          ),
          const SizedBox(height: 20),
          _buildExpirySection(
            context,
            title: 'Expired',
            description: 'Past the recorded expiry date.',
            items: expired,
            expiredOnly: true,
            emptyMessage: 'No expired items.',
          ),
        ],
      ),
    );
  }

  // Reusable section for both "Expiring soon" and "Expired" (Yola).
  Widget _buildExpirySection(
    BuildContext context, {
    required String title,
    required String description,
    required List<FoodItem> items,
    required bool expiredOnly,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: title,
          count: items.length,
          subtitle: description,
          actionLabel: items.isEmpty ? null : 'View all',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExpiringSoonScreen(
                appState: widget.appState,
                expiredOnly: expiredOnly,
                windowDays: _expiringSoonWindowDays,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(emptyMessage, style: const TextStyle(color: AppTheme.muted)),
          )
        else
          ...items.take(4).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ItemCard(
                    item: item,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(appState: widget.appState, item: item),
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  /// Epic 6 — entry point to recipe suggestions. Recipes themselves are
  /// only fetched when the screen is opened, not on Home.
  Widget _buildRecipeIdeas(BuildContext context, AppState state) {
    // Same rule as the server: expired items can't be used in a recipe
    // (AC 6.1.5), so they don't count as "expiring soon" here.
    final expiringCount = state.expiringWithin(3).where((i) => i.daysLeft >= 0 && i.quantity > 0).length;
    final subtitle = expiringCount > 0
        ? 'Use up $expiringCount ${expiringCount == 1 ? 'item' : 'items'} expiring in the next 3 days'
        : 'Get ideas for what to cook with the food you have';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Card(
        color: AppTheme.honeyLight,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RecipeSuggestionsScreen(appState: widget.appState),
          )),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 17),
            child: Row(
              children: [
                const IconBadge(icon: Icons.restaurant_menu, fill: AppTheme.saffron),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recipe ideas',
                        style: TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontWeight: FontWeight.w600,
                          fontSize: 19,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF5A4A2A), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, List<FoodItem> results) {
    if (results.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text('No items match your search.', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ItemCard(
              item: results[i],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ItemDetailScreen(appState: widget.appState, item: results[i]),
              )),
            ),
          ),
          childCount: results.length,
        ),
      ),
    );
  }
}
