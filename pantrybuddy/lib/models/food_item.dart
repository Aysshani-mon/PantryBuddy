/// Where an item is physically stored. Matches schema.sql `storage_types`
/// (FRIDGE/FREEZER/PANTRY).
///
/// Epic 2 — AC 2.2.1 / AC 2.5.1
enum StorageLocation { fridge, freezer, pantry }

extension StorageLocationLabel on StorageLocation {
  String get label {
    switch (this) {
      case StorageLocation.fridge:
        return 'Fridge';
      case StorageLocation.freezer:
        return 'Freezer';
      case StorageLocation.pantry:
        return 'Pantry';
    }
  }
}

/// Product category — matches schema.sql `product_categories`. The item
/// name itself stays free text for now (per team decision) rather than
/// picking from the `products` catalog, but the category is kept aligned
/// with the DB's taxonomy so the real shelf-life dataset (keyed by
/// category/product + storage type, same as `shelf_life_rules`) can slot
/// in later without another rename.
///
/// Last synced against insert_static_data.sql's 16 categories — note
/// "Household Items" no longer exists in the real data (replaced by more
/// specific categories like Eggs, Baked Goods, etc.), and category_ids 9
/// and 10 are intentionally skipped in the source data.
enum ProductCategory {
  dairy,
  meat,
  seafood,
  vegetables,
  fruits,
  snacks,
  beverages,
  frozenFood,
  babyFood,
  bakedGoods,
  condimentsSaucesCannedGoods,
  grainsBeansPasta,
  shelfStableFoods,
  vegetarianProteins,
  deliPreparedFoods,
  eggs,
}

extension ProductCategoryLabel on ProductCategory {
  String get label {
    switch (this) {
      case ProductCategory.dairy:
        return 'Dairy';
      case ProductCategory.meat:
        return 'Meat';
      case ProductCategory.seafood:
        return 'Seafood';
      case ProductCategory.vegetables:
        return 'Vegetables';
      case ProductCategory.fruits:
        return 'Fruits';
      case ProductCategory.snacks:
        return 'Snacks';
      case ProductCategory.beverages:
        return 'Beverages';
      case ProductCategory.frozenFood:
        return 'Frozen Food';
      case ProductCategory.babyFood:
        return 'Baby Food';
      case ProductCategory.bakedGoods:
        return 'Baked Goods';
      case ProductCategory.condimentsSaucesCannedGoods:
        return 'Condiments, Sauces & Canned Goods';
      case ProductCategory.grainsBeansPasta:
        return 'Grains, Beans & Pasta';
      case ProductCategory.shelfStableFoods:
        return 'Shelf-Stable Foods';
      case ProductCategory.vegetarianProteins:
        return 'Vegetarian Proteins';
      case ProductCategory.deliPreparedFoods:
        return 'Deli & Prepared Foods';
      case ProductCategory.eggs:
        return 'Eggs';
    }
  }

  /// Matches schema.sql `product_categories.is_fresh_food`.
  bool get isFreshFood => const {
        ProductCategory.dairy,
        ProductCategory.meat,
        ProductCategory.seafood,
        ProductCategory.vegetables,
        ProductCategory.fruits,
        ProductCategory.vegetarianProteins,
        ProductCategory.deliPreparedFoods,
        ProductCategory.eggs,
      }.contains(this);
}

/// What happened to an item once it left the inventory. Matches
/// schema.sql `inventory_items.status` (IN_STOCK maps to isActive==true;
/// this enum covers the two "resolved" states the schema supports).
/// NOTE: a DONATED option was considered but the current schema's status
/// enum doesn't include it — dropped for now, can be added back once the
/// schema/DB team adds it.
enum ItemDisposition { consumed, discarded }

/// A single inventory item. Matches schema.sql `inventory_items`
/// (simplified: `name` stays free text here instead of a `product_id`
/// FK into a `products` catalog, per team decision).
///
/// Epic 2 — AC 2.1.1 / AC 2.6.1
class FoodItem {
  final String id;
  final String householdId;
  String name;
  double quantity;
  String unit;
  StorageLocation storageLocation;
  ProductCategory category;
  DateTime useByDate;
  final DateTime addedAt;
  final String addedByUserId;
  ItemDisposition? disposition; // null while still active in the inventory (IN_STOCK)
  DateTime? resolvedAt;

  FoodItem({
    required this.id,
    required this.householdId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.storageLocation,
    required this.category,
    required this.useByDate,
    required this.addedByUserId,
    DateTime? addedAt,
    this.disposition,
    this.resolvedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  bool get isActive => disposition == null;

  int get daysLeft {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final useByDateOnly =
        DateTime(useByDate.year, useByDate.month, useByDate.day);
    return useByDateOnly.difference(todayDateOnly).inDays;
  }

  /// Whether this item falls within its reminder window (Epic 2/3 — used
  /// for the "Expiring Soon" section, AC 2.3.1).
  bool isExpiringWithin(int days) => isActive && daysLeft <= days;
}
