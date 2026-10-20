// CivilHand Service & Category Models
// Pure Dart, integer paise representations for all financial values

class ServiceCategory {
  final String id;
  final String name;
  final String slug;
  final String iconName;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconName,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    iconName: json['icon_name'] as String,
  );
}

class ServiceItem {
  final String id;
  final String categoryId;
  final String name;
  final String description;
  final int minEstimatePaise;
  final int maxEstimatePaise;
  final int visitingChargePaise;
  final int durationMinutes;
  final double commissionPct;
  final int fixedPlatformFeePaise;

  const ServiceItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.minEstimatePaise,
    required this.maxEstimatePaise,
    required this.visitingChargePaise,
    required this.durationMinutes,
    required this.commissionPct,
    required this.fixedPlatformFeePaise,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
    id: json['id'] as String,
    categoryId: json['category_id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    minEstimatePaise: (json['min_estimate_paise'] as num).toInt(),
    maxEstimatePaise: (json['max_estimate_paise'] as num).toInt(),
    visitingChargePaise: (json['visiting_charge_paise'] as num).toInt(),
    durationMinutes: (json['typical_duration_minutes'] as num).toInt(),
    commissionPct: (json['commission_percentage'] as num).toDouble(),
    fixedPlatformFeePaise: (json['fixed_platform_fee_paise'] as num).toInt(),
  );

  String get visitingChargeRupees => '₹${(visitingChargePaise / 100).toStringAsFixed(0)}';
  String get estimateRangeRupees => '₹${(minEstimatePaise / 100).toStringAsFixed(0)} - ₹${(maxEstimatePaise / 100).toStringAsFixed(0)}';
}
