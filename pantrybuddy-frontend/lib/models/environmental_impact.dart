import 'food_item.dart';

/// Epic 8 — the server-calculated environmental impact of food wasted in
/// one period. Every number here comes from the backend
/// (GET /households/:id/environmental-impact); Flutter only displays it.
///
/// Total CO2e = Σ (quantity in kg × lifecycle emission factor), using
/// Poore & Nemecek (2018) factors via Our World in Data.
enum EnvironmentalImpactStatus {
  /// Calculated normally.
  ready,

  /// The emission-factor reference data hasn't been loaded into the
  /// database yet — show a "coming soon" state, not an error.
  pendingData,
}

/// Why a single wasted item was or wasn't included in the total.
enum ImpactItemStatus { estimated, noFactor, unknownWeight }

/// How an item's quantity was turned into kilograms.
enum WeightBasis { mass, volume, unitWeight }

class CategoryImpact {
  const CategoryImpact({required this.category, required this.kgCo2e, required this.kgWasted, required this.itemCount});
  final ProductCategory category;
  final double kgCo2e;
  final double kgWasted;
  final int itemCount;

  factory CategoryImpact.fromJson(Map<String, dynamic> json) => CategoryImpact(
        category: _categoryFrom(json['category']),
        kgCo2e: (json['kgCo2e'] as num).toDouble(),
        kgWasted: (json['kgWasted'] as num).toDouble(),
        itemCount: json['itemCount'] as int,
      );
}

class DailyImpact {
  const DailyImpact({required this.date, required this.kgCo2e});
  /// The user's local calendar day (no time-of-day) — the server already
  /// grouped by local day using the offset the app sent, so this is
  /// parsed as a plain date, NOT through the UTC timestamp parser.
  final DateTime date;
  final double kgCo2e;

  factory DailyImpact.fromJson(Map<String, dynamic> json) {
    final parts = (json['date'] as String).split('-').map(int.parse).toList();
    return DailyImpact(date: DateTime(parts[0], parts[1], parts[2]), kgCo2e: (json['kgCo2e'] as num).toDouble());
  }
}

class ImpactItem {
  const ImpactItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.status,
    this.kgWasted,
    this.weightBasis,
    this.emissionFactor,
    this.factorEntity,
    this.kgCo2e,
  });

  final String id;
  final String name;
  final ProductCategory category;
  final double quantity;
  final String unit;
  final ImpactItemStatus status;
  final double? kgWasted;
  final WeightBasis? weightBasis;
  /// kg CO2e per kg of this food.
  final double? emissionFactor;
  /// Which Our World in Data food product the factor came from.
  final String? factorEntity;
  final double? kgCo2e;

  factory ImpactItem.fromJson(Map<String, dynamic> json) => ImpactItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: _categoryFrom(json['category']),
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String,
        status: ImpactItemStatus.values.byName(json['status'] as String),
        kgWasted: (json['kgWasted'] as num?)?.toDouble(),
        weightBasis: json['weightBasis'] == null ? null : WeightBasis.values.byName(json['weightBasis'] as String),
        emissionFactor: (json['emissionFactor'] as num?)?.toDouble(),
        factorEntity: json['factorEntity'] as String?,
        kgCo2e: (json['kgCo2e'] as num?)?.toDouble(),
      );
}

class EnvironmentalImpact {
  const EnvironmentalImpact({
    required this.status,
    this.totalKgCo2e = 0,
    this.totalKgWasted = 0,
    this.previousTotalKgCo2e,
    this.wastedItemCount = 0,
    this.estimatedItemCount = 0,
    this.noFactorCount = 0,
    this.unknownWeightCount = 0,
    this.hasApproximateWeights = false,
    this.byCategory = const [],
    this.daily = const [],
    this.items = const [],
  });

  const EnvironmentalImpact.pending() : this(status: EnvironmentalImpactStatus.pendingData);

  final EnvironmentalImpactStatus status;
  final double totalKgCo2e;
  final double totalKgWasted;
  /// Same total for the previous period — null when there isn't enough
  /// activity in one of the two periods to compare meaningfully.
  final double? previousTotalKgCo2e;
  final int wastedItemCount;
  final int estimatedItemCount;
  final int noFactorCount;
  final int unknownWeightCount;
  /// True if any included item's weight was approximated (volume → kg,
  /// or an average weight per piece/pack) rather than entered in g/kg.
  final bool hasApproximateWeights;
  final List<CategoryImpact> byCategory;
  final List<DailyImpact> daily;
  final List<ImpactItem> items;

  int get excludedItemCount => noFactorCount + unknownWeightCount;

  /// Positive = more CO2e than the previous period.
  double? get changeVsPrevious => previousTotalKgCo2e == null ? null : totalKgCo2e - previousTotalKgCo2e!;

  factory EnvironmentalImpact.fromJson(Map<String, dynamic> json) {
    if (json['status'] == 'pendingData') return const EnvironmentalImpact.pending();
    final excluded = (json['excludedCounts'] as Map<String, dynamic>?) ?? const {};
    return EnvironmentalImpact(
      status: EnvironmentalImpactStatus.ready,
      totalKgCo2e: (json['totalKgCo2e'] as num).toDouble(),
      totalKgWasted: (json['totalKgWasted'] as num).toDouble(),
      previousTotalKgCo2e: (json['previousTotalKgCo2e'] as num?)?.toDouble(),
      wastedItemCount: json['wastedItemCount'] as int,
      estimatedItemCount: json['estimatedItemCount'] as int,
      noFactorCount: (excluded['noFactor'] as int?) ?? 0,
      unknownWeightCount: (excluded['unknownWeight'] as int?) ?? 0,
      hasApproximateWeights: json['hasApproximateWeights'] as bool? ?? false,
      byCategory: ((json['byCategory'] as List?) ?? const [])
          .map((e) => CategoryImpact.fromJson(e as Map<String, dynamic>))
          .toList(),
      daily: ((json['daily'] as List?) ?? const []).map((e) => DailyImpact.fromJson(e as Map<String, dynamic>)).toList(),
      items: ((json['items'] as List?) ?? const []).map((e) => ImpactItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

ProductCategory _categoryFrom(Object? name) {
  if (name is String) {
    for (final c in ProductCategory.values) {
      if (c.name == name) return c;
    }
  }
  return ProductCategory.shelfStableFoods; // same fallback the backend uses
}
