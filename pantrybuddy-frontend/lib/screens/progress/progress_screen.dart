import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../models/food_item.dart';
import '../../models/insights_data.dart';
import '../../services/insights_service.dart';
import '../../services/price_estimate_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/trend_chart.dart';

const _categoryEmoji = <ProductCategory, String>{
  ProductCategory.dairy: '🥛',
  ProductCategory.meat: '🥩',
  ProductCategory.seafood: '🐟',
  ProductCategory.vegetables: '🥦',
  ProductCategory.fruits: '🍎',
  ProductCategory.snacks: '🍪',
  ProductCategory.beverages: '🥤',
  ProductCategory.frozenFood: '🧊',
  ProductCategory.babyFood: '🍼',
  ProductCategory.bakedGoods: '🍞',
  ProductCategory.condimentsSaucesCannedGoods: '🥫',
  ProductCategory.grainsBeansPasta: '🍚',
  ProductCategory.shelfStableFoods: '📦',
  ProductCategory.vegetarianProteins: '🌱',
  ProductCategory.deliPreparedFoods: '🍱',
  ProductCategory.eggs: '🥚',
};

/// Epic 5 — Progress tab.
/// Both views ("My Stats" and "Household") share the exact same card
/// layout (stat cards, trend, category breakdown, estimated value,
/// suggestion) — the only difference is the data scope (userId filter).
/// Household additionally gets a "why food was wasted" breakdown, using
/// the app's real DiscardReason data.
///
/// 5.1 — My Stats view.
/// 5.2 — Household view (scope only; the buying-frequency angle from the
/// original story is intentionally not built as a separate feature here —
/// see chat for why).
/// 5.3 — the trend chart, present in both views.
/// 5.4 — the suggestion card, present in both views.
/// 5.5 — estimated value card (placeholder pricing — see
/// PriceEstimateService; database team's CSV isn't ready yet).
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  InsightsPeriod _period = InsightsPeriod.weekly;
  DateTime _anchor = DateTime.now();
  bool _householdView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) {
            final state = widget.appState;
            final range = InsightsService.rangeFor(_period, _anchor);
            final userId = _householdView ? null : state.currentUser?.id;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildViewToggle(),
                const SizedBox(height: 16),
                _buildPeriodToggle(),
                const SizedBox(height: 12),
                _buildRangeNav(range),
                const SizedBox(height: 16),
                ..._buildStatsSection(state, range, userId, isHousehold: _householdView),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Progress', style: Theme.of(context).textTheme.headlineSmall),
              Text('Track your household\'s food journey', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.seedColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.eco_outlined, color: AppTheme.seedColor),
        ),
      ],
    );
  }

  Widget _buildViewToggle() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('My Stats')),
        ButtonSegment(value: true, label: Text('Household')),
      ],
      selected: {_householdView},
      onSelectionChanged: (s) => setState(() => _householdView = s.first),
    );
  }

  Widget _buildPeriodToggle() {
    return SegmentedButton<InsightsPeriod>(
      segments: const [
        ButtonSegment(value: InsightsPeriod.weekly, label: Text('Weekly')),
        ButtonSegment(value: InsightsPeriod.monthly, label: Text('Monthly')),
      ],
      selected: {_period},
      onSelectionChanged: (s) => setState(() {
        _period = s.first;
        _anchor = DateTime.now();
      }),
    );
  }

  Widget _buildRangeNav(DateRange range) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _anchor = InsightsService.shift(range, _period, forward: false).start;
              }),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text(InsightsService.label(range, _period), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                _anchor = InsightsService.shift(range, _period, forward: true).start;
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== My Stats + Household sections ====================

  List<Widget> _buildStatsSection(AppState state, DateRange range, String? userId, {required bool isHousehold}) {
    final items = state.items;
    final summary = InsightsService.summarize(items, range, userId: userId);
    final trend = InsightsService.trend(items, range, userId: userId);

    if (!isHousehold) {
      // My Stats: stat cards (unchanged) + trend + "Your contribution"
      // (replaces the comparison/breakdown/estimate/suggestion cards).
      final household = InsightsService.summarize(items, range, userId: null);
      final addedCount = items.where((i) => i.addedByUserId == userId && range.contains(i.addedAt)).length;
      return [
        _buildStatCardsRow(summary),
        const SizedBox(height: 16),
        _buildTrendCard(trend),
        const SizedBox(height: 16),
        _buildYourContributionCard(state, summary, household, addedCount),
      ];
    }

    // Household: unchanged from before (trend just no longer plots Stored,
    // handled globally in TrendChart).
    final breakdown = InsightsService.categoryBreakdown(items, range, userId: userId);
    final suggestion = InsightsService.generateSuggestion(
      breakdown.isEmpty ? [const CategoryWasteCount(ProductCategory.shelfStableFoods, 0)] : breakdown,
      summary,
    );
    final wastedItems = items.where((i) =>
        i.disposition == ItemDisposition.discarded && i.resolvedAt != null && range.contains(i.resolvedAt!));
    final estimatedValue = PriceEstimateService.estimateValue(wastedItems);

    return [
      _buildStatCardsRow(summary),
      const SizedBox(height: 16),
      _buildComparisonCard(summary),
      const SizedBox(height: 16),
      _buildTrendCard(trend),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildCategoryBreakdownCard(breakdown)),
          const SizedBox(width: 12),
          Expanded(child: _buildEstimatedValueCard(estimatedValue)),
        ],
      ),
      const SizedBox(height: 16),
      _buildDiscardReasonCard(InsightsService.discardReasonBreakdown(items, range)),
      const SizedBox(height: 16),
      _buildSuggestionCard(suggestion),
    ];
  }

  /// User's share of the household's consumed/wasted items this period —
  /// replaces the score/breakdown/estimate/suggestion cards on My Stats.
  Widget _buildYourContributionCard(AppState state, PeriodSummary mine, PeriodSummary household, int addedCount) {
    final consumedPct = household.consumed == 0 ? 0 : ((mine.consumed / household.consumed) * 100).round();
    final wastedPct = household.wasted == 0 ? 0 : ((mine.wasted / household.wasted) * 100).round();
    final name = state.currentUser?.name.trim() ?? '';
    final initials = name.isEmpty
        ? '?'
        : name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.heroFill(AppTheme.seedColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              const Text('Your contribution', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Text('$consumedPct% of household food consumed',
              style: AppTheme.statNumberStyle.copyWith(fontSize: 21, color: Colors.white)),
          const SizedBox(height: 6),
          Text('$wastedPct% of household food wasted',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 12),
          Text(
            '${mine.consumed} item${mine.consumed == 1 ? '' : 's'} used • $addedCount added • ${mine.wasted} discarded',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardsRow(PeriodSummary summary) {
    Widget statCard(String label, int value, Color color, Color fill) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 4),
              Text('$value', style: AppTheme.statNumberStyle.copyWith(fontSize: 24, color: color)),
              Text('items', style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        statCard('Consumed', summary.consumed, AppTheme.seedColor, AppTheme.basilLight),
        const SizedBox(width: 10),
        statCard('Stored', summary.stored, AppTheme.ocean, AppTheme.oceanLight),
        const SizedBox(width: 10),
        statCard('Wasted', summary.wasted, AppTheme.paprika, AppTheme.paprikaLight),
      ],
    );
  }

  /// The "X% less/more waste" comparison card — kept from the original
  /// design even though the score ring next to it was removed. Compares
  /// this period's reduction score to the immediately preceding period's.
  Widget _buildComparisonCard(PeriodSummary summary) {
    final change = summary.percentChangeVsPrevious;
    final improved = change <= 0; // score dropping = less waste = good

    if (summary.previousScore == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Not enough history yet to compare with the previous period.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        ),
      );
    }

    return Card(
      color: improved ? AppTheme.basilLight : AppTheme.paprikaLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(improved ? Icons.trending_up : Icons.trending_down,
                color: improved ? AppTheme.seedColor : AppTheme.paprika),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: '${change.abs()}% ',
                          style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17,
                            color: improved ? AppTheme.seedColor : AppTheme.paprika,
                          ),
                        ),
                        TextSpan(text: improved ? 'less waste' : 'more waste', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    improved ? 'Great job! You wasted less food this period.' : 'A bit more waste than last period — check the tip below.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(List<TrendPoint> trend) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trends (items)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Wrap(
              spacing: 14,
              children: [
                _LegendDot(color: AppTheme.seedColor, label: 'Consumed'),
                _LegendDot(color: AppTheme.paprika, label: 'Wasted'),
              ],
            ),
            const SizedBox(height: 12),
            TrendChart(points: trend),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(List<CategoryWasteCount> breakdown) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category breakdown\n(wasted items)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 12),
            if (breakdown.isEmpty)
              Text('No wasted items this period 🎉', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))
            else
              ...breakdown.take(4).map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(_categoryEmoji[c.category] ?? '🍽️', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.category.label, style: const TextStyle(fontSize: 12.5))),
                        Text('${c.count} item${c.count == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimatedValueCard(double estimatedValue) {
    return Card(
      color: AppTheme.honeyLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Estimated value\nwasted', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                Icon(Icons.info_outline, size: 15, color: Colors.grey.shade600),
              ],
            ),
            const SizedBox(height: 10),
            Text('\$${estimatedValue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.paprika)),
            const Text('Estimated', style: TextStyle(fontSize: 11, color: AppTheme.paprika, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Placeholder pricing — will use real item prices once the dataset is ready.',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// Household-only. Uses the real DiscardReason data (spoiled / expired
  /// not spoiled / quality declined / other) rather than inventing a
  /// richer "root cause" taxonomy that isn't actually captured anywhere.
  Widget _buildDiscardReasonCard(List<DiscardReasonCount> reasons) {
    final total = reasons.fold<int>(0, (sum, r) => sum + r.count);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why food was wasted', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Based on the reason picked when discarding an item.', style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
            const SizedBox(height: 14),
            if (reasons.isEmpty)
              Text('No discarded items with a reason recorded this period.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))
            else
              ...reasons.map((r) {
                final pct = total == 0 ? 0.0 : r.count / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(r.reason.label, style: const TextStyle(fontSize: 12.5))),
                          Text('${r.count} · ${(pct * 100).round()}%',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          color: AppTheme.paprika,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(WasteSuggestion suggestion) {
    return Card(
      color: AppTheme.honeyLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline, color: AppTheme.honey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(suggestion.headline, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(suggestion.detail, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }
}
