// CivilHand Labor Profile & Financial Dues Model

class LaborProfileModel {
  final String id;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final String bio;
  final int experienceYears;
  final bool isOnline;
  final bool isOccupied;
  final String kycStatus;
  final double ratingAvg;
  final int ratingCount;
  final double bayesianRating;
  final int completedJobsCount;

  // Financial Balances in paise
  final int grossCashCollectedPaise;
  final int platformDuesPaise;
  final int cashLimitPaise;
  final bool isCashLocked;

  const LaborProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.avatarUrl,
    required this.bio,
    required this.experienceYears,
    required this.isOnline,
    required this.isOccupied,
    required this.kycStatus,
    required this.ratingAvg,
    required this.ratingCount,
    required this.bayesianRating,
    required this.completedJobsCount,
    required this.grossCashCollectedPaise,
    required this.platformDuesPaise,
    required this.cashLimitPaise,
    required this.isCashLocked,
  });

  factory LaborProfileModel.fromJson(Map<String, dynamic> json, Map<String, dynamic>? profileJson) => LaborProfileModel(
    id: json['id'] as String,
    fullName: profileJson?['full_name'] as String? ?? 'Professional',
    phone: profileJson?['phone'] as String? ?? '',
    avatarUrl: profileJson?['avatar_url'] as String?,
    bio: json['bio'] as String? ?? '',
    experienceYears: (json['experience_years'] as num?)?.toInt() ?? 0,
    isOnline: json['is_online'] as bool? ?? false,
    isOccupied: json['is_occupied'] as bool? ?? false,
    kycStatus: json['kyc_status'] as String? ?? 'pending',
    ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 5.0,
    ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    bayesianRating: (json['bayesian_rating'] as num?)?.toDouble() ?? 4.0,
    completedJobsCount: (json['completed_jobs_count'] as num?)?.toInt() ?? 0,
    grossCashCollectedPaise: (json['gross_cash_collected_paise'] as num?)?.toInt() ?? 0,
    platformDuesPaise: (json['platform_dues_paise'] as num?)?.toInt() ?? 0,
    cashLimitPaise: (json['cash_limit_paise'] as num?)?.toInt() ?? 500000,
    isCashLocked: json['is_cash_locked'] as bool? ?? false,
  );

  double get cashExposureRatio => platformDuesPaise / (cashLimitPaise == 0 ? 1 : cashLimitPaise);
  String get platformDuesRupees => '₹${(platformDuesPaise / 100).toStringAsFixed(0)}';
  String get cashLimitRupees => '₹${(cashLimitPaise / 100).toStringAsFixed(0)}';
}
