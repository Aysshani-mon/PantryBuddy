import 'package:flutter/material.dart';

import '../models/environmental_impact.dart';
import '../models/food_item.dart';
import '../models/insights_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Epic 8 — Environmental Impact Insights card for the Progress tab.
///
/// Covers the three user stories: the estimated CO2e of food wasted this
/// period (with the previous-period change), the breakdown by category,
/// and a day-by-day trend.
///
/// Unlike the rest of the Progress tab (which computes from
/// AppState.items synchronously), this fetches from the backend. It
/// refetches only when the period changes or [wasteSignature] changes
/// (i.e. something was discarded/edited) — NOT on every 8-second poll
/// rebuild — and keeps showing the last result while a refresh is in
/// flight so the card doesn't flicker.
class EnvironmentalImpactCard extends StatefulWidget {
  const EnvironmentalImpactCard({
    super.key,
    required this.appState,
    required this.range,
    required this.previousRange,
    required this.period,
    required this.wasteSignature,
  });

  final AppState appState;
  final DateRange range;
  final DateRange previousRange;
  final InsightsPeriod period;
  /// Changes whenever the set of discarded items changes — see
  /// ProgressScreen._wasteSignature.
  final int wasteSignature;

  @override
  State<EnvironmentalImpactCard> createState() => _EnvironmentalImpactCardState();
}

class _EnvironmentalImpactCardState extends State<EnvironmentalImpactCard> {
  EnvironmentalImpact? _data;
  Object? _error;
  bool _loading = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EnvironmentalImpactCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final periodChanged = oldWidget.range.start != widget.range.start || oldWidget.range.end != widget.range.end;
    if (periodChanged) _data = null; // don't show last week's number under this week's label
    if (periodChanged || oldWidget.wasteSignature != widget.wasteSignature) _load();
  }

  /// Called from initState/didUpdateWidget (both always followed by a
  /// build, so no setState needed for the loading flag) and from the
  /// retry button via [_retry].
  Future<void> _load() async {
    final id = ++_requestId;
    _loading = true;
    _error = null;
    try {
      final result = await widget.appState.getEnvironmentalImpact(range: widget.range, previous: widget.previousRange);
      if (!mounted || id != _requestId) return; // a newer request superseded this one
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _retry() {
    _load();
    setState(() {});
  }

  String get _periodWord => widget.period == InsightsPeriod.weekly ? 'week' : 'month';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_outlined, size: 18, color: AppTheme.ocean),
                const SizedBox(width: 6),
                const Expanded(child: Text('Environmental impact', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                if (_loading && _data != null)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                IconButton(
                  icon: Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                  tooltip: 'How this is calculated',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showMethodDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildBody(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    final data = _data;
    if (data == null && _error != null) {
      return [
        Text('Couldn\'t load the environmental impact estimate.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
        TextButton(onPressed: _retry, child: const Text('Try again')),
      ];
    }
    if (data == null) {
      return const [
        Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
      ];
    }
    if (data.status == EnvironmentalImpactStatus.pendingData) {
      return [
        Text(
          'Coming soon — we\'re still preparing the emission data used to estimate the carbon footprint of wasted food.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
        ),
      ];
    }
    if (data.wastedItemCount == 0) {
      return [
        Text('0 kg CO₂e', style: AppTheme.statNumberStyle.copyWith(fontSize: 24, color: AppTheme.seedColor)),
        const SizedBox(height: 4),
        Text('No food wasted this $_periodWord 🌱', style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
        if (data.changeVsPrevious != null && data.previousTotalKgCo2e! > 0) ...[
          const SizedBox(height: 10),
          _buildComparison(data),
        ],
      ];
    }

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_formatKg(data.totalKgCo2e),
              style: AppTheme.statNumberStyle.copyWith(fontSize: 26, color: AppTheme.paprika)),
          const SizedBox(width: 6),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('kg CO₂e', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.paprika)),
          ),
        ],
      ),
      Text('Estimated · from ${_formatKg(data.totalKgWasted)} kg of wasted food',
          style: const TextStyle(fontSize: 11, color: AppTheme.paprika, fontWeight: FontWeight.w600)),
      if (data.changeVsPrevious != null) ...[
        const SizedBox(height: 12),
        _buildComparison(data),
      ],
      if (data.daily.length > 1 && data.estimatedItemCount > 0) ...[
        const SizedBox(height: 16),
        const Text('Day by day', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        _DailyBars(points: data.daily, weekly: widget.period == InsightsPeriod.weekly),
      ],
      if (data.byCategory.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('By category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        ..._buildCategoryRows(data),
      ],
      const SizedBox(height: 10),
      _buildCoverageNote(data),
    ];
  }

  Widget _buildComparison(EnvironmentalImpact data) {
    final change = data.changeVsPrevious!;
    // Absolute kg rather than a percentage — a near-zero previous period
    // can't turn a small change into a huge, meaningless percentage.
    final same = change.abs() < 0.005;
    final better = change < 0;
    final color = same ? Colors.grey.shade700 : (better ? AppTheme.seedColor : AppTheme.paprika);
    final text = same
        ? 'About the same as last $_periodWord'
        : '${_formatKg(change.abs())} kg CO₂e ${better ? 'less' : 'more'} than last $_periodWord';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: same ? Colors.grey.shade100 : (better ? AppTheme.basilLight : AppTheme.paprikaLight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(same ? Icons.trending_flat : (better ? Icons.trending_down : Icons.trending_up), size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5))),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryRows(EnvironmentalImpact data) {
    final total = data.totalKgCo2e;
    return data.byCategory.take(5).map((c) {
      final share = total <= 0 ? 0.0 : c.kgCo2e / total;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(c.category.label, style: const TextStyle(fontSize: 12.5))),
                Text('${_formatKg(c.kgCo2e)} kg · ${(share * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.ocean,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildCoverageNote(EnvironmentalImpact data) {
    final lines = <String>[];
    if (data.excludedItemCount > 0) {
      lines.add('Based on ${data.estimatedItemCount} of ${data.wastedItemCount} wasted items — '
          '${data.excludedItemCount} couldn\'t be estimated yet (no emission or weight data for that item).');
    }
    if (data.hasApproximateWeights) {
      lines.add('Some weights are approximate (items measured in pieces, packs or litres).');
    }
    lines.add('Lifecycle estimate covering production and supply chain, not just landfill.');
    return Text(lines.join(' '), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600));
  }

  void _showMethodDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How this is estimated'),
        content: const SingleChildScrollView(
          child: Text(
            'For each wasted item, we convert the amount to kilograms and multiply it by a lifecycle emission '
            'factor for that type of food (kg CO₂e per kg). The total is the sum across all wasted items:\n\n'
            'Total CO₂e = Σ (quantity in kg × emission factor)\n\n'
            'The factors already include all greenhouse gases converted to CO₂-equivalent, and cover the '
            'food\'s whole lifecycle — farming, processing, transport and retail — so they show the impact '
            'of producing food that was never eaten, not only what happens in landfill.\n\n'
            'Items entered in pieces, packs or litres use an average weight, so those figures are approximate. '
            'Items we don\'t have data for are left out rather than guessed.\n\n'
            'Source: Poore, J. & Nemecek, T. (2018), Science 360(6392), 987–992, via Our World in Data. '
            'Calculation method adapted from the GHG Protocol.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }
}

String _formatKg(double kg) => kg >= 10 ? kg.toStringAsFixed(1) : kg.toStringAsFixed(2);

/// Simple bar chart of daily kg CO2e. Not the shared TrendChart, which
/// plots integer item counts on a line.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.points, required this.weekly});
  final List<DailyImpact> points;
  final bool weekly;

  static const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final max = points.fold<double>(0, (m, p) => p.kgCo2e > m ? p.kgCo2e : m);
    const chartHeight = 70.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final p in points)
                Expanded(
                  child: Tooltip(
                    message: '${p.date.day}/${p.date.month}: ${_formatKg(p.kgCo2e)} kg CO₂e',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: weekly ? 4 : 1),
                      child: Container(
                        // A real zero still gets a thin visible stub, so
                        // "no waste that day" reads as data, not missing.
                        height: max <= 0 ? 2 : (p.kgCo2e / max * (chartHeight - 2)) + 2,
                        decoration: BoxDecoration(
                          color: p.kgCo2e > 0 ? AppTheme.ocean : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (weekly)
          Row(
            children: [
              for (final p in points)
                Expanded(
                  child: Text(_weekdayLetters[p.date.weekday - 1],
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${points.first.date.day}/${points.first.date.month}',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
              Text('${points.last.date.day}/${points.last.date.month}',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
            ],
          ),
        Text('Peak: ${_formatKg(max)} kg CO₂e', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
      ],
    );
  }
}
