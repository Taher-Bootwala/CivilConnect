// CivilHand Riverpod Providers
// Pure, minimal, zero-codegen provider definitions (Ponytail style)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/service_model.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseService(client);
});

// Categories FutureProvider
final categoriesProvider = FutureProvider<List<ServiceCategory>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getCategories();
});

// Category Services Family Provider
final servicesByCategoryProvider = FutureProvider.family<List<ServiceItem>, String>((ref, categoryId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getServices(categoryId);
});

// Active Customer Bookings Stream Provider
final customerBookingsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final userId = service.currentUser?.id;
  if (userId == null) return const Stream.empty();
  return service.streamCustomerBookings(userId);
});

// Active Worker Bookings Stream Provider
final workerBookingsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final userId = service.currentUser?.id;
  if (userId == null) return const Stream.empty();
  return service.streamWorkerBookings(userId);
});
