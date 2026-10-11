import 'package:flutter/material.dart';
import 'dart:async';
import '../../state/app_state.dart';
import '../../models/food_item.dart';
import '../../widgets/item_card.dart';
import 'item_detail_screen.dart';
import 'add_edit_item_screen.dart';
import 'receipt_scan_screen.dart';
import '../donations/donate_items_screen.dart';
import '../donations/my_donations_screen.dart';
import '../../theme/app_theme.dart';
import 'multi_item_scan_screen.dart';
import '../../widgets/brand.dart';

/// AC 2.5.1 — items grouped under storage-location tabs (All/Fridge/
/// Freezer/Pantry), each showing an item count.
/// Search bar shown on both the home screen and here (AC).
class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen(
    {
      super.key,
      required this.appState,
      this.requestedLocation,
      this.navigationRequest = 0,
    }
  );
  final AppState appState;
  final StorageLocation? requestedLocation;
  final int navigationRequest;

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  // Added a getter to request the tab index based on the requested location.
  int get _requestedTabIndex {
    final location = widget.requestedLocation;

    return location == null
      ? 0
      : StorageLocation.values.indexOf(location) + 1;
  }
  // Yola

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      // Modified the length of the TabController to include the
      // "All" tab and the storage location tabs.
      length: StorageLocation.values.length + 1,
      vsync: this,
      initialIndex: _requestedTabIndex,
      // Yola
    );
  }

  // Added an additional override to handle the navigation request
  // and requested location changes, resetting the search bar and
  // tab index accordingly.
  @override
  void didUpdateWidget(covariant InventoryListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.navigationRequest != widget.navigationRequest ||
      oldWidget.requestedLocation != widget.requestedLocation) {
      _searchDebounce?.cancel();
      _searchController.clear();
      _tabController.index = _requestedTabIndex;
    }
  }
  // Yola

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    // Added a dispose call for the TabController to prevent memory leaks.
    _tabController.dispose();
    // Yola
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
      appBar: AppBar(title: const Text('Inventory')),
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final state = widget.appState;
          final searchQuery = _searchController.text;
          final searchResults =
              searchQuery.trim().isEmpty ? null : state.search(searchQuery);

          final all = state.activeItems;
          final byLocation = {
            for (final loc in StorageLocation.values) loc: state.itemsIn(loc),
          };

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _buildSearchBar(),
              ),
              if (searchResults != null)
                Expanded(child: _buildSearchResults(context, searchResults))
              else ...[
                _buildDonateCard(context),
                _buildActions(context),
                BrandTabTrack(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    tabs: [
                      Tab(height: 40, text: 'All ${all.length}'),
                      ...StorageLocation.values
                          .map((loc) => Tab(height: 40, text: '${loc.label} ${byLocation[loc]!.length}')),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(context, all),
                      ...StorageLocation.values.map((loc) => _buildList(context, byLocation[loc]!)),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Add / scan actions as labelled buttons above the tabs (they used to
  /// be three unlabelled floating buttons in the corner).
  Widget _buildActions(BuildContext context) {
    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              icon: Icons.add,
              label: 'Add item',
              onTap: () => open(AddEditItemScreen(appState: widget.appState)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionTile(
              icon: Icons.receipt_long_outlined,
              label: 'Scan receipt',
              onTap: () => open(ReceiptScanScreen(appState: widget.appState)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionTile(
              // Epic 4 — several items from one photo (Gemini).
              icon: Icons.shopping_basket_outlined,
              label: 'Scan items',
              onTap: () => open(MultiItemScanScreen(appState: widget.appState)),
            ),
          ),
        ],
      ),
    );
  }

  /// Epic 7 — donate several items in one go, and see past donations.
  Widget _buildDonateCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              const Icon(Icons.volunteer_activism_outlined, color: AppTheme.seedColor),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Donate food you won\'t use', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MyDonationsScreen(appState: widget.appState),
                )),
                child: const Text('My donations'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DonateItemsScreen(appState: widget.appState),
                )),
                child: const Text('Donate'),
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
        hintText: 'Search your inventory...',
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

  Widget _buildSearchResults(BuildContext context, List<FoodItem> results) {
    if (results.isEmpty) {
      return Center(
        child: Text('No items match your search.', style: TextStyle(color: Colors.grey.shade600)),
      );
    }
    final sorted = [...results]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => ItemCard(
        item: sorted[i],
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ItemDetailScreen(appState: widget.appState, item: sorted[i]),
        )),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<FoodItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text('No items here yet.', style: TextStyle(color: Colors.grey.shade600)),
      );
    }
    final sorted = [...items]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => ItemCard(
        item: sorted[i],
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ItemDetailScreen(appState: widget.appState, item: sorted[i]),
        )),
      ),
    );
  }
}

/// Compact labelled button (icon above text) for the Inventory actions row.
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Same saffron as the Home "Add item" button.
    const fg = AppTheme.ink;
    return Material(
      color: AppTheme.saffron,
      shape: const LedgeBorder(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
