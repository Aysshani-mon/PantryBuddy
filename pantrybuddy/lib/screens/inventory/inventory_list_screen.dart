import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../models/food_item.dart';
import '../../widgets/item_card.dart';
import 'item_detail_screen.dart';
import 'add_edit_item_screen.dart';

/// AC 2.5.1 — items grouped under storage-location tabs (All/Fridge/
/// Freezer/Pantry), each showing an item count.
class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final state = widget.appState;
          final all = state.activeItems;
          final byLocation = {
            for (final loc in StorageLocation.values) loc: state.itemsIn(loc),
          };

          return Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: 'All (${all.length})'),
                  ...StorageLocation.values
                      .map((loc) => Tab(text: '${loc.label} (${byLocation[loc]!.length})')),
                ],
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AddEditItemScreen(appState: widget.appState),
        )),
        child: const Icon(Icons.add),
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
