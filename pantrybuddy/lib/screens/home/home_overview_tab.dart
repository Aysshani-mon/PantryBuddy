import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../models/app_user.dart';
import '../../models/food_item.dart';
import '../../widgets/item_card.dart';
import '../../widgets/app_logo.dart';
import '../inventory/expiring_soon_screen.dart';
import '../inventory/item_detail_screen.dart';
import '../inventory/add_edit_item_screen.dart';

const _expiringSoonWindowDays = 3;

/// AC 1.2.2 — household name + user avatar in the header.
/// AC 2.2.1 — total count + per-category breakdown.
/// AC 2.3.1 / AC 2.4.1 — expiring soon preview + "View All".
/// AC 2.7.1 — search across all locations.
class HomeOverviewTab extends StatefulWidget {
  const HomeOverviewTab({super.key, required this.appState});
  final AppState appState;

  @override
  State<HomeOverviewTab> createState() => _HomeOverviewTabState();
}

class _HomeOverviewTabState extends State<HomeOverviewTab> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) {
            final state = widget.appState;
            final searchQuery = _searchController.text;
            final searchResults =
                searchQuery.trim().isEmpty ? null : state.search(searchQuery);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context, state)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSearchBar(),
                  ),
                ),
                if (searchResults != null)
                  _buildSearchResults(context, searchResults)
                else ...[
                  SliverToBoxAdapter(child: _buildSummary(context, state)),
                  SliverToBoxAdapter(child: _buildExpiringSoon(context, state)),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AddEditItemScreen(appState: widget.appState),
        )),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState state) {
    final user = state.currentUser;
    final household = state.currentHousehold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppLogo(markSize: 150, direction: Axis.horizontal),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade100,
                child: Text(
                  user != null ? AvatarCatalog.emojiFor(user.avatarKey) : '🥕',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(household?.name ?? 'Your household',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text('Hi, ${user?.name ?? ''} 👋', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
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

  Widget _buildSummary(BuildContext context, AppState state) {
    final active = state.activeItems;
    final byLocation = {
      for (final loc in StorageLocation.values)
        loc: active.where((i) => i.storageLocation == loc).length,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${active.length}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('items in your inventory'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: StorageLocation.values.map((loc) {
                  return Expanded(
                    child: Column(
                      children: [
                        Text('${byLocation[loc]}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(loc.label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiringSoon(BuildContext context, AppState state) {
    final expiring = state.expiringWithin(_expiringSoonWindowDays);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expiring Soon', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ExpiringSoonScreen(appState: widget.appState),
                )),
                child: const Text('View All'),
              ),
            ],
          ),
          if (expiring.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Nothing expiring in the next $_expiringSoonWindowDays days 🎉',
                  style: TextStyle(color: Colors.grey.shade600)),
            )
          else
            ...expiring.take(4).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ItemCard(
                    item: item,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ItemDetailScreen(appState: widget.appState, item: item),
                    )),
                  ),
                )),
        ],
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
