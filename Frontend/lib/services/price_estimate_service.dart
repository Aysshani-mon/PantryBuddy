import '../models/food_item.dart';

/// User Story 5.5 — estimates the RM value of wasted food.
///
/// Priority order, per the database team's price handover:
/// 1. The user's own entered [FoodItem.price] (a real purchase price) —
///    used as-is, since it's an actual total, not a per-unit figure.
/// 2. [FoodItem.publicEstimatedPrice] — a server-computed fallback from
///    real PriceCatcher data, when this product has a mapped reference.
/// 3. The category-level placeholder average below — only reached for
///    items with neither a user price nor a public reference (e.g.
///    something added as a loose category reference rather than one of
///    the priced catalogue products).
///
/// Every value shown from this service should stay visibly labelled as an
/// *estimate* in the UI (AC 5.5) — never presented as an exact figure,
/// since only case 1 is a real number the rest are estimates/guesses.
class PriceEstimateService {
  /// Rough average price of one package/item in RM — last-resort
  /// placeholder only.
  static const Map<ProductCategory, double> _avgUnitPrice = {
    ProductCategory.dairy: 4.50,
    ProductCategory.meat: 8.00,
    ProductCategory.seafood: 9.00,
    ProductCategory.vegetables: 2.50,
    ProductCategory.fruits: 3.00,
    ProductCategory.snacks: 3.50,
    ProductCategory.beverages: 3.00,
    ProductCategory.frozenFood: 6.00,
    ProductCategory.babyFood: 5.00,
    ProductCategory.bakedGoods: 4.00,
    ProductCategory.condimentsSaucesCannedGoods: 3.50,
    ProductCategory.grainsBeansPasta: 3.00,
    ProductCategory.shelfStableFoods: 3.50,
    ProductCategory.vegetarianProteins: 4.50,
    ProductCategory.deliPreparedFoods: 6.50,
    ProductCategory.eggs: 4.00,
  };

  static double _placeholderFor(ProductCategory category) => _avgUnitPrice[category] ?? 4.00;

  /// Units where the quantity is a count of things you buy (2 cans,
  /// 3 packs). For weights and volumes (g, kg, mL, L) the quantity is NOT a
  /// number of packages — "500 g" is one bag, not 500 of them.
  static const Set<String> _countUnits = {'pcs', 'pack', 'box', 'bottle', 'can', 'dozen'};

  /// How many packages [item] represents, for multiplying a per-package
  /// price. Weight/volume items count as one package.
  static double _packagesFor(FoodItem item) {
    final unit = item.unit.trim().toLowerCase();
    if (!_countUnits.contains(unit)) return 1;
    return item.quantity > 0 ? item.quantity : 1;
  }

  /// The single-item value used everywhere below: user price first, then
  /// the public estimate, then the category placeholder as a last resort.
  ///
  /// Both fallbacks are prices for ONE package, so they're multiplied by
  /// the number of packages, never by a weight. (Previously a 500 g item
  /// was priced as 500 x the package price, which inflated the total.)
  static double valueFor(FoodItem item) {
    if (item.price != null) return item.price!;
    final packages = _packagesFor(item);
    if (item.publicEstimatedPrice != null) return item.publicEstimatedPrice! * packages;
    return _placeholderFor(item.category) * packages;
  }

  /// Whether [valueFor] had to fall back to the category placeholder for
  /// this item (i.e. neither a real user price nor public data existed) —
  /// lets the UI optionally flag "rough estimate" vs. "based on real data".
  static bool isPlaceholder(FoodItem item) => item.price == null && item.publicEstimatedPrice == null;

  /// Estimated total value of [items] (already filtered to whichever set
  /// — e.g. wasted-this-week — the caller wants priced).
  static double estimateValue(Iterable<FoodItem> items) {
    var total = 0.0;
    for (final item in items) {
      total += valueFor(item);
    }
    return total;
  }
}
