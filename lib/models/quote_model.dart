// CivilHand Quote Model for final post-work billing

enum QuoteStatus {
  pending,
  approved,
  disputed,
  revised,
  superseded;

  static QuoteStatus fromString(String val) {
    return QuoteStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => QuoteStatus.pending,
    );
  }
}

class QuoteModel {
  final String id;
  final String bookingId;
  final String laborId;
  final int version;
  final int laborChargePaise;
  final int materialChargePaise;
  final int visitingChargePaise;
  final int fixedPlatformFeePaise;
  final int commissionPaise;
  final int taxPaise;
  final int totalCustomerPaise;
  final int netLaborPaise;
  final String? explanationNote;
  final List<String> beforePhotos;
  final List<String> afterPhotos;
  final List<String> materialReceiptPhotos;
  final QuoteStatus status;
  final String? customerResponseNote;

  const QuoteModel({
    required this.id,
    required this.bookingId,
    required this.laborId,
    required this.version,
    required this.laborChargePaise,
    required this.materialChargePaise,
    required this.visitingChargePaise,
    required this.fixedPlatformFeePaise,
    required this.commissionPaise,
    required this.taxPaise,
    required this.totalCustomerPaise,
    required this.netLaborPaise,
    this.explanationNote,
    this.beforePhotos = const [],
    this.afterPhotos = const [],
    this.materialReceiptPhotos = const [],
    required this.status,
    this.customerResponseNote,
  });

  factory QuoteModel.fromJson(Map<String, dynamic> json) => QuoteModel(
    id: json['id'] as String,
    bookingId: json['booking_id'] as String,
    laborId: json['labor_id'] as String,
    version: (json['version'] as num).toInt(),
    laborChargePaise: (json['labor_charge_paise'] as num).toInt(),
    materialChargePaise: (json['material_charge_paise'] as num).toInt(),
    visitingChargePaise: (json['visiting_charge_paise'] as num).toInt(),
    fixedPlatformFeePaise: (json['fixed_platform_fee_paise'] as num).toInt(),
    commissionPaise: (json['commission_paise'] as num).toInt(),
    taxPaise: (json['tax_paise'] as num).toInt(),
    totalCustomerPaise: (json['total_customer_paise'] as num).toInt(),
    netLaborPaise: (json['net_labor_paise'] as num).toInt(),
    explanationNote: json['explanation_note'] as String?,
    beforePhotos: (json['before_photos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    afterPhotos: (json['after_photos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    materialReceiptPhotos: (json['material_receipt_photos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    status: QuoteStatus.fromString(json['status'] as String? ?? 'pending'),
    customerResponseNote: json['customer_response_note'] as String?,
  );

  String get totalCustomerRupees => '₹${(totalCustomerPaise / 100).toStringAsFixed(0)}';
  String get netLaborRupees => '₹${(netLaborPaise / 100).toStringAsFixed(0)}';
}
