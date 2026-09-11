import '../models/food_item.dart';

/// User Story 5.5 — estimates the $ value of wasted food.
///
/// PLACEHOLDER PRICING: the database team's price-per-product CSV isn't
/// ready yet, so this uses rough category-level average unit prices as a
/// stand-in — same "stub now, swap later" pattern as ShelfLifeService and
/// CategoryDefaultsService. Once the real dataset lands, replace
/// [_avgUnitPrice] with a lookup keyed by product name/category (ideally
/// via a new PriceRepository, mirroring ShelfLifeRepository's shape) —
/// keep [estimateValue]'s signature the same so the UI doesn't change.
///
/// Every value shown from this service should stay visibly labelled as an
/// *estimate* in the UI (AC 5.5) — never presented as an exact figure,
/// since the underlying price is a guess, not sourced data.
class PriceEstimateService {
  /// Rough average price per unit (treated as "per item", regardless of
  /// the item's actual unit/quantity — a deliberately simple placeholder).
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

  static double _priceFor(ProductCategory category) => _avgUnitPrice[category] ?? 4.00;

  /// Estimated total value of [items] (already filtered to whichever set
  /// — e.g. wasted-this-week — the caller wants priced), using each
  /// item's quantity x its category's placeholder unit price.
  static double estimateValue(Iterable<FoodItem> items) {
    var total = 0.0;
    for (final item in items) {
      total += _priceFor(item.category) * item.quantity;
    }
    return total;
  }
}
