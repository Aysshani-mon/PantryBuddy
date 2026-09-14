import '../models/food_item.dart';
import '../models/insights_data.dart';

/// Computes every number the Progress tab shows (Epic 5), purely from the
/// household's existing item history — no new backend endpoints needed,
/// since FoodItem already carries everything required (addedAt,
/// addedByUserId, disposition, resolvedAt, category, quantity).
///
/// Definitions used throughout (flagging these since the user stories
/// don't pin them down exactly):
/// - "Wasted" = disposition == discarded only. Donated items are tracked
///   separately and don't count as waste (AC 5.1/5.5) — they left the
///   inventory on purpose, for a good outcome.
/// - "Stored" is a snapshot (items active as of the END of the period),
///   not a flow count like consumed/wasted — reconstructed from
///   addedAt/resolvedAt so it's correct for past periods too, not just
///   "right now".
/// - The reduction score only considers items actually resolved within
///   the period (consumed+donated+wasted) — still-stored items are
///   neither a good nor bad sign yet, so they're excluded from the score
///   itself (though still shown as their own stat).
class InsightsService {
  // ==================== Date ranges ====================

  static DateRange rangeFor(InsightsPeriod period, DateTime anchor) {
    if (period == InsightsPeriod.weekly) {
      final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
      final start = DateTime(monday.year, monday.month, monday.day);
      final end = DateTime(start.year, start.month, start.day + 6, 23, 59, 59, 999);
      return DateRange(start, end);
    }
    final start = DateTime(anchor.year, anchor.month, 1);
    final end = DateTime(anchor.year, anchor.month + 1, 0, 23, 59, 59, 999); // day 0 of next month = last day of this one
    return DateRange(start, end);
  }

  static DateRange shift(DateRange current, InsightsPeriod period, {required bool forward}) {
    final sign = forward ? 1 : -1;
    if (period == InsightsPeriod.weekly) {
      final newAnchor = current.start.add(Duration(days: 7 * sign));
      return rangeFor(period, newAnchor);
    }
    final newAnchor = DateTime(current.start.year, current.start.month + sign, 1);
    return rangeFor(period, newAnchor);
  }

  static String label(DateRange range, InsightsPeriod period) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    if (period == InsightsPeriod.monthly) {
      return '${months[range.start.month - 1]} ${range.start.year}';
    }
    final sameMonth = range.start.month == range.end.month;
    final startStr = '${months[range.start.month - 1]} ${range.start.day}';
    final endStr = sameMonth ? '${range.end.day}' : '${months[range.end.month - 1]} ${range.end.day}';
    return '$startStr – $endStr';
  }

  // ==================== Core predicates ====================

  static bool _activeAt(FoodItem item, DateTime instant) =>
      !item.addedAt.isAfter(instant) && (item.resolvedAt == null || item.resolvedAt!.isAfter(instant));

  static Iterable<FoodItem> _scoped(List<FoodItem> items, String? userId) =>
      userId == null ? items : items.where((i) => i.addedByUserId == userId);

  // ==================== 5.1 / 5.2 — period summary ====================

  /// [userId] null = whole household (5.2); non-null = just that member's
  /// own added items (5.1 — "my contribution").
  static PeriodSummary summarize(List<FoodItem> allItems, DateRange range, {String? userId}) {
    final scoped = _scoped(allItems, userId);

    final consumed = scoped.where((i) =>
        i.disposition == ItemDisposition.consumed &&
        i.resolvedAt != null &&
        range.contains(i.resolvedAt!)).length;
    final wasted = scoped.where((i) =>
        i.disposition == ItemDisposition.discarded &&
        i.resolvedAt != null &&
        range.contains(i.resolvedAt!)).length;
    final donated = scoped.where((i) =>
        i.disposition == ItemDisposition.donated &&
        i.resolvedAt != null &&
        range.contains(i.resolvedAt!)).length;
    final stored = scoped.where((i) => _activeAt(i, range.end)).length;

    final score = calculateScore(consumed: consumed, wasted: wasted, donated: donated);

    final prevRange = DateRange(
      range.start.subtract(range.end.difference(range.start) + const Duration(days: 1)),
      range.start.subtract(const Duration(milliseconds: 1)),
    );
    final prevConsumed = scoped.where((i) =>
        i.disposition == ItemDisposition.consumed && i.resolvedAt != null && prevRange.contains(i.resolvedAt!)).length;
    final prevWasted = scoped.where((i) =>
        i.disposition == ItemDisposition.discarded && i.resolvedAt != null && prevRange.contains(i.resolvedAt!)).length;
    final prevDonated = scoped.where((i) =>
        i.disposition == ItemDisposition.donated && i.resolvedAt != null && prevRange.contains(i.resolvedAt!)).length;
    final hasPrevData = prevConsumed + prevWasted + prevDonated > 0;

    return PeriodSummary(
      consumed: consumed,
      wasted: wasted,
      donated: donated,
      stored: stored,
      score: score,
      previousScore: hasPrevData ? calculateScore(consumed: prevConsumed, wasted: prevWasted, donated: prevDonated) : null,
    );
  }

  /// % of items resolved this period that were consumed or donated, rather
  /// than wasted. 100 when nothing was resolved yet (a fresh household, or
  /// a period with no activity, isn't "bad" — it's just no data).
  static int calculateScore({required int consumed, required int wasted, required int donated}) {
    final total = consumed + wasted + donated;
    if (total == 0) return 100;
    return ((consumed + donated) / total * 100).round();
  }

  // ==================== 5.3 — trend over time ====================

  /// AC 5.3.7 — a day within the range with genuinely no activity shows
  /// as a real, plotted zero; a day that hasn't happened yet is simply
  /// never generated as a point at all (not "zero", not plotted).
  static List<TrendPoint> trend(List<FoodItem> allItems, DateRange range, {String? userId}) {
    final scoped = _scoped(allItems, userId).toList();
    final points = <TrendPoint>[];
    var day = DateTime(range.start.year, range.start.month, range.start.day);
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final lastDay = DateTime(range.end.year, range.end.month, range.end.day);
    final lastPlottableDay = lastDay.isAfter(todayDateOnly) ? todayDateOnly : lastDay;

    while (!day.isAfter(lastPlottableDay)) {
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
      final consumed = scoped.where((i) =>
          i.disposition == ItemDisposition.consumed &&
          i.resolvedAt != null &&
          i.resolvedAt!.year == day.year && i.resolvedAt!.month == day.month && i.resolvedAt!.day == day.day).length;
      final wasted = scoped.where((i) =>
          i.disposition == ItemDisposition.discarded &&
          i.resolvedAt != null &&
          i.resolvedAt!.year == day.year && i.resolvedAt!.month == day.month && i.resolvedAt!.day == day.day).length;
      final stored = scoped.where((i) => _activeAt(i, dayEnd)).length;
      points.add(TrendPoint(date: day, consumed: consumed, wasted: wasted, stored: stored));
      day = day.add(const Duration(days: 1));
    }
    return points;
  }

  // ==================== Category breakdown (wasted items) ====================

  static List<CategoryWasteCount> categoryBreakdown(List<FoodItem> allItems, DateRange range, {String? userId}) {
    final scoped = _scoped(allItems, userId).where((i) =>
        i.disposition == ItemDisposition.discarded && i.resolvedAt != null && range.contains(i.resolvedAt!));
    final counts = <ProductCategory, int>{};
    for (final item in scoped) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    final list = counts.entries.map((e) => CategoryWasteCount(e.key, e.value)).toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  // ==================== 5.4 — waste reduction suggestion ====================

  /// Rule-based, not ML — see the chat explanation: this is explainable
  /// and directly traceable to the person's own data, which matters more
  /// here than model sophistication, and there's no training data for a
  /// fresh household anyway.
  ///
  /// AC 5.4.3 — a recorded discard REASON is checked first, since "why"
  /// something was wasted is more actionable than "what category" it was
  /// in (the two aren't mutually exclusive — a dominant reason wins when
  /// one exists; category is the fallback for when reasons are spread out
  /// or unrecorded).
  static WasteSuggestion generateSuggestion(
    List<CategoryWasteCount> breakdown,
    PeriodSummary summary, {
    List<DiscardReasonCount> reasonBreakdown = const [],
  }) {
    if (summary.wasted == 0) {
      return const WasteSuggestion(
        headline: 'No waste this period!',
        detail: 'Keep it up — whatever you\'re doing is working.',
      );
    }

    // Reason-based first (AC 5.4.3).
    if (reasonBreakdown.isNotEmpty) {
      final topReason = reasonBreakdown.first;
      final reasonShare = summary.wasted == 0 ? 0.0 : topReason.count / summary.wasted;
      if (reasonShare >= 0.4) {
        return WasteSuggestion(
          headline: '"${topReason.reason.label}" is your most common reason for waste',
          detail: _tipForReason(topReason.reason),
        );
      }
    }

    // Category-based fallback.
    final top = breakdown.first; // breakdown is pre-sorted, highest count first
    final share = summary.wasted == 0 ? 0.0 : top.count / summary.wasted;
    if (share >= 0.4) {
      return WasteSuggestion(
        headline: 'You wasted more ${top.category.label} than anything else',
        detail: _tipFor(top.category),
      );
    }
    return const WasteSuggestion(
      headline: 'Your waste is spread across a few categories',
      detail: 'Try checking use-by dates before your next shop, so you know what to use up first.',
    );
  }

  /// AC 5.4.3's own example: "suggesting a smaller purchase quantity when
  /// 'Bought too much' was selected" — this is that rule, plus one for
  /// each of the other recorded reasons.
  static String _tipForReason(DiscardReason reason) {
    switch (reason) {
      case DiscardReason.overbought:
        return 'Try buying a smaller quantity next time — or split a bulk pack with someone in the household.';
      case DiscardReason.spoiled:
        return 'This usually means it needs colder or better storage — double check your fridge temperature, or move it somewhere cooler sooner after buying.';
      case DiscardReason.expiredNotSpoiled:
        return 'Looked fine but the date had passed — try setting a reminder a couple of days earlier, or move older stock to the front so it gets used first.';
      case DiscardReason.qualityDeclined:
        return 'Consider an airtight container or a different shelf — how something is stored often affects how fast it declines, not just how long it sits.';
      case DiscardReason.other:
        return 'Take a look at the pattern behind these — a specific reason next time will help pinpoint a more useful tip.';
    }
  }

  static String _tipFor(ProductCategory category) {
    switch (category) {
      case ProductCategory.vegetables:
      case ProductCategory.fruits:
        return 'Try buying a smaller amount next time, or freeze what you won\'t use in a few days.';
      case ProductCategory.dairy:
      case ProductCategory.eggs:
        return 'Consider buying smaller pack sizes, or double-check you\'re using older stock first.';
      case ProductCategory.bakedGoods:
        return 'Bread and baked goods freeze well — try freezing half if you won\'t finish it in time.';
      case ProductCategory.meat:
      case ProductCategory.seafood:
        return 'Consider freezing portions you won\'t cook within a couple of days of buying.';
      case ProductCategory.deliPreparedFoods:
        return 'Try buying smaller portions of prepared food, since it tends to have the shortest shelf life.';
      default:
        return 'Try buying a smaller quantity next time, and using older items first.';
    }
  }

  // ==================== 5.5 — estimated value wasted ====================
  // See PriceEstimateService — kept separate since it's the one piece
  // waiting on real data from the team, not something this class computes.

  // ==================== Household-only: why food was wasted ====================

  /// Breakdown by the user's own stated DiscardReason. [userId] null =
  /// household-wide; non-null = just that member's own added items.
  static List<DiscardReasonCount> discardReasonBreakdown(List<FoodItem> allItems, DateRange range, {String? userId}) {
    final wasted = _scoped(allItems, userId).where((i) =>
        i.disposition == ItemDisposition.discarded &&
        i.resolvedAt != null &&
        range.contains(i.resolvedAt!) &&
        i.discardReason != null);
    final counts = <DiscardReason, int>{};
    for (final item in wasted) {
      counts[item.discardReason!] = (counts[item.discardReason!] ?? 0) + 1;
    }
    final list = counts.entries.map((e) => DiscardReasonCount(e.key, e.value)).toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  // ==================== 5.2 — household purchase rhythm ====================

  /// Not period-scoped — this looks at the item's whole purchase history
  /// to answer "how often do we typically buy this", independent of
  /// whoever did the buying (AC 5.2).
  static List<PurchaseRhythm> purchaseRhythms(List<FoodItem> allItems) {
    final byName = <String, List<FoodItem>>{};
    for (final item in allItems) {
      final key = item.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      byName.putIfAbsent(key, () => []).add(item);
    }

    final rhythms = <PurchaseRhythm>[];
    byName.forEach((key, group) {
      if (group.length < 2) return; // need at least 2 purchases to measure a gap
      group.sort((a, b) => a.addedAt.compareTo(b.addedAt));
      final gaps = <int>[];
      for (var i = 1; i < group.length; i++) {
        gaps.add(group[i].addedAt.difference(group[i - 1].addedAt).inDays);
      }
      final avg = gaps.reduce((a, b) => a + b) / gaps.length;
      rhythms.add(PurchaseRhythm(
        itemName: group.last.name, // most recent casing/spelling
        category: group.last.category,
        averageDaysBetween: avg,
        purchaseCount: group.length,
      ));
    });

    rhythms.sort((a, b) => a.averageDaysBetween.compareTo(b.averageDaysBetween)); // most frequent first
    return rhythms;
  }
}
