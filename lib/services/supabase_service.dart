// CivilHand Supabase Service
// Handles Auth, Realtime streaming, RPC calls, and Edge Functions dispatch

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_model.dart';

class SupabaseService {
  final SupabaseClient client;

  SupabaseService(this.client);

  // 1. Auth & Profiles
  User? get currentUser => client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Future<void> signInWithPhone(String phone) async {
    await client.auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyPhoneOtp(String phone, String token) async {
    return await client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // 2. Services & Categories
  Future<List<ServiceCategory>> getCategories() async {
    final res = await client
        .from('service_categories')
        .select()
        .eq('is_active', true)
        .order('display_order');
    return (res as List).map((e) => ServiceCategory.fromJson(e)).toList();
  }

  Future<List<ServiceItem>> getServices(String categoryId) async {
    final res = await client
        .from('services')
        .select()
        .eq('category_id', categoryId)
        .eq('is_active', true);
    return (res as List).map((e) => ServiceItem.fromJson(e)).toList();
  }

  // 3. Proximity Search for Pros
  Future<List<Map<String, dynamic>>> findNearbyPros({
    required double latitude,
    required double longitude,
    required String serviceId,
  }) async {
    final res = await client.rpc('find_nearby_eligible_pros', params: {
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_service_id': serviceId,
      'p_max_distance_meters': 20000,
      'p_limit': 15,
    });
    return List<Map<String, dynamic>>.from(res as List);
  }

  // 4. Booking Operations via Edge Functions
  Future<Map<String, dynamic>> dispatchBooking({
    required String serviceId,
    required double latitude,
    required double longitude,
    required String addressSnapshot,
    String? addressLandmark,
    required String problemDescription,
    List<String> problemPhotos = const [],
    String? selectedLaborId,
    String dispatchMode = 'auto',
  }) async {
    final response = await client.functions.invoke('dispatch-booking', body: {
      'service_id': serviceId,
      'latitude': latitude,
      'longitude': longitude,
      'address_snapshot': addressSnapshot,
      'address_landmark': addressLandmark,
      'problem_description': problemDescription,
      'problem_photos': problemPhotos,
      'dispatch_mode': dispatchMode,
      'selected_labor_id': selectedLaborId,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> respondBooking({
    required String bookingId,
    required String action, // 'accept' or 'reject'
  }) async {
    await client.functions.invoke('respond-booking', body: {
      'booking_id': bookingId,
      'action': action,
    });
  }

  Future<void> verifyJobStatus({
    required String bookingId,
    required String action, // 'on_the_way', 'arrive', 'start_work', 'complete_work'
    String? otp,
  }) async {
    await client.functions.invoke('verify-job', body: {
      'booking_id': bookingId,
      'action': action,
      'otp': otp,
    });
  }

  Future<void> submitQuote({
    required String bookingId,
    required int laborChargePaise,
    int materialChargePaise = 0,
    int visitingChargePaise = 0,
    String? explanationNote,
    List<String> beforePhotos = const [],
    List<String> afterPhotos = const [],
  }) async {
    await client.functions.invoke('quote-lifecycle', body: {
      'action': 'submit_quote',
      'booking_id': bookingId,
      'labor_charge_paise': laborChargePaise,
      'material_charge_paise': materialChargePaise,
      'visiting_charge_paise': visitingChargePaise,
      'explanation_note': explanationNote,
      'before_photos': beforePhotos,
      'after_photos': afterPhotos,
    });
  }

  Future<void> approveQuote({required String bookingId, required String quoteId}) async {
    await client.functions.invoke('quote-lifecycle', body: {
      'action': 'approve_quote',
      'booking_id': bookingId,
      'quote_id': quoteId,
    });
  }

  Future<void> disputeQuote({
    required String bookingId,
    required String quoteId,
    required String reason,
    int? counterAmountPaise,
  }) async {
    await client.functions.invoke('quote-lifecycle', body: {
      'action': 'dispute_quote',
      'booking_id': bookingId,
      'quote_id': quoteId,
      'reason': reason,
      'counter_amount_paise': counterAmountPaise,
    });
  }

  Future<void> confirmCashPayment({required String bookingId}) async {
    await client.functions.invoke('payment-handler', body: {
      'action': 'confirm_cash_payment',
      'booking_id': bookingId,
    });
  }

  // 5. Realtime Booking Stream
  Stream<List<Map<String, dynamic>>> streamCustomerBookings(String customerId) {
    return client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamWorkerBookings(String laborId) {
    return client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('labor_id', laborId)
        .order('created_at', ascending: false);
  }

  // 6. In-App Messaging (Masked Identity)
  Stream<List<Map<String, dynamic>>> streamChatMessages(String bookingId) {
    return client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId)
        .order('created_at', ascending: true);
  }

  Future<void> sendChatMessage({
    required String bookingId,
    required String senderId,
    required String messageText,
    String? mediaUrl,
  }) async {
    await client.from('chat_messages').insert({
      'booking_id': bookingId,
      'sender_id': senderId,
      'message_text': messageText,
      'media_url': mediaUrl,
    });
  }

  // 7. Ratings & Bayesian Review Loop
  Future<void> submitRating({
    required String bookingId,
    required String customerId,
    required String laborId,
    required int ratingScore,
    List<String> tags = const [],
    String? reviewText,
  }) async {
    await client.from('ratings').insert({
      'booking_id': bookingId,
      'customer_id': customerId,
      'labor_id': laborId,
      'rating_score': ratingScore,
      'tags': tags,
      'review_text': reviewText,
    });
  }

  // 8. Professional KYC Submission
  Future<void> submitKyc({
    required String laborId,
    required String idType,
    required String idNumberMasked,
    required String idFrontUrl,
    String? idBackUrl,
  }) async {
    await client.from('labor_kyc').insert({
      'labor_id': laborId,
      'id_type': idType,
      'id_number_masked': idNumberMasked,
      'id_document_front_url': idFrontUrl,
      'id_document_back_url': idBackUrl,
      'status': 'submitted',
    });

    await client.from('labor_profiles').update({
      'kyc_status': 'submitted',
    }).eq('id', laborId);
  }

  // 9. Payouts & Balance Inquiries
  Future<Map<String, dynamic>> getWithdrawableBalance() async {
    final res = await client.functions.invoke('payout-handler', body: {
      'action': 'get_balance',
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> requestPayout(int amountPaise) async {
    final res = await client.functions.invoke('payout-handler', body: {
      'action': 'request_payout',
      'amount_paise': amountPaise,
    });
    return res.data as Map<String, dynamic>;
  }

  // 10. In-App Notifications
  Stream<List<Map<String, dynamic>>> streamNotifications(String userId) {
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }
}

