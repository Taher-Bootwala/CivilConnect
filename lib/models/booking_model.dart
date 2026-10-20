// CivilHand Booking Model & Booking State Enum
// ignore_for_file: constant_identifier_names

enum BookingStatus {
  REQUESTED,
  ACCEPTED,
  ON_THE_WAY,
  ARRIVED,
  IN_PROGRESS,
  WORK_DONE,
  AMOUNT_PENDING_APPROVAL,
  APPROVED,
  DISPUTED,
  PAYMENT_PENDING,
  PAID,
  CLOSED,
  CANCELLED,
  EXPIRED;

  static BookingStatus fromString(String val) {
    return BookingStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => BookingStatus.REQUESTED,
    );
  }
}

class BookingModel {
  final String id;
  final String bookingCode;
  final String customerId;
  final String? laborId;
  final String serviceId;
  final BookingStatus status;
  final DateTime scheduledAt;
  final String addressSnapshot;
  final String? addressLandmark;
  final String problemDescription;
  final List<String> problemPhotos;
  final String? startOtp;
  final DateTime createdAt;

  const BookingModel({
    required this.id,
    required this.bookingCode,
    required this.customerId,
    this.laborId,
    required this.serviceId,
    required this.status,
    required this.scheduledAt,
    required this.addressSnapshot,
    this.addressLandmark,
    required this.problemDescription,
    this.problemPhotos = const [],
    this.startOtp,
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
    id: json['id'] as String,
    bookingCode: json['booking_code'] as String,
    customerId: json['customer_id'] as String,
    laborId: json['labor_id'] as String?,
    serviceId: json['service_id'] as String,
    status: BookingStatus.fromString(json['status'] as String? ?? 'REQUESTED'),
    scheduledAt: DateTime.parse(json['scheduled_at'] as String),
    addressSnapshot: json['address_snapshot'] as String? ?? '',
    addressLandmark: json['address_landmark'] as String?,
    problemDescription: json['problem_description'] as String? ?? '',
    problemPhotos: (json['problem_photos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    startOtp: json['start_otp'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
