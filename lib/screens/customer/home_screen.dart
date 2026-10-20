// CivilHand Customer Home & Service Discovery Screen
// Fluid cards, category bottom sheet, and live booking tracking

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../models/service_model.dart';
import '../../models/quote_model.dart';
import 'quote_approval_sheet.dart';
import 'rating_review_screen.dart';
import '../chat/chat_screen.dart';
import '../auth/phone_auth_screen.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSignOut;
  final String? userName;

  const CustomerHomeScreen({super.key, this.onSignOut, this.userName});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}


class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  String _selectedCategorySlug = 'plumbing';
  Map<String, dynamic>? _mockActiveBooking;

  @override
  void initState() {
    super.initState();
    // Starts with null active booking for new user accounts
    _mockActiveBooking = null;
  }


  void _openBookingSheet(ServiceItem service) {
    final problemController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.slate200, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            Text(service.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(service.description, style: const TextStyle(fontSize: 13, color: AppTheme.slate500)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoPill('Visiting Fee', service.visitingChargeRupees),
                  _infoPill('Estimated', service.estimateRangeRupees),
                  _infoPill('Duration', '${service.durationMinutes} mins'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Describe Your Problem', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: problemController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g., Kitchen mixer tap dripping continuously...',
                filled: true,
                fillColor: AppTheme.slate100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _mockActiveBooking = {
                    'id': 'b-demo-${DateTime.now().millisecondsSinceEpoch}',
                    'code': 'CH-REQ-${DateTime.now().millisecond}',
                    'service_name': service.name,
                    'status': 'REQUESTED',
                    'start_otp': '${1000 + (DateTime.now().millisecond % 9000)}',
                    'address': 'Current Location: Navrangpura, Ahmedabad',
                    'worker_name': 'Searching nearby professionals...',
                  };
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.primaryIndigo,
                    content: Text('Booking request created for ${service.name}!'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppTheme.primaryIndigo,
              ),
              child: const Text('Confirm Request (No Upfront Payment)', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuoteSheet() {
    final quote = QuoteModel(
      id: 'q-demo-1',
      bookingId: 'b-demo-101',
      laborId: 'l-demo-1',
      version: 1,
      laborChargePaise: 45000, // ₹450
      materialChargePaise: 18000, // ₹180 (spindle replacement)
      visitingChargePaise: 9900, // ₹99
      fixedPlatformFeePaise: 4900, // ₹49
      commissionPaise: 8235, // 15% on 450+99
      taxPaise: 0,
      totalCustomerPaise: 77800, // ₹778
      netLaborPaise: 64665,
      explanationNote: 'Replaced internal brass spindle valve to completely stop leakage.',
      status: QuoteStatus.pending,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuoteApprovalSheet(
        quote: quote,
        onApproved: () async {
          await Future.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          Navigator.pop(context);
          setState(() {
            _mockActiveBooking = null; // Booking settled and closed
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.successGreen,
              content: Text('Payment Approved! Thank you for using CivilHand.'),
            ),
          );
        },
        onDisputed: (reason, counter) async {
          Navigator.pop(context);
          setState(() {
            if (_mockActiveBooking != null) {
              _mockActiveBooking!['status'] = 'DISPUTED';
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.dangerRose,
              content: Text('Dispute raised: "$reason". Professional notified.'),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppTheme.primaryIndigo),
                const SizedBox(width: 4),
                const Text('Navrangpura, Ahmedabad', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.slate500),
              ],
            ),
            Text(
              widget.userName != null ? 'Hello, ${widget.userName}' : 'Verified Home Services',
              style: const TextStyle(fontSize: 12, color: AppTheme.slate500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          if (_mockActiveBooking != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.slate800),
              tooltip: 'Active Job Chat',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatScreen(
                      bookingId: 'b-demo-101',
                      bookingCode: 'CH-PLUMB-921',
                      recipientName: 'Ramesh Kumar (Plumber)',
                    ),
                  ),
                );
              },
            ),
          if (widget.onSignOut != null)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppTheme.slate700),
              tooltip: 'Sign Out / Switch Account',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text('Are you sure you want to sign out of your account?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRose),
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onSignOut!();
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],


      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Live Active Booking Card (if active)
            if (_mockActiveBooking != null) ...[
              _buildActiveBookingCard(),
              const SizedBox(height: 24),
            ],

            // 2. Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.slate200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: const [
                  Icon(Icons.search_rounded, color: AppTheme.slate500),
                  SizedBox(width: 10),
                  Text('Search plumber, AC service, carpenter...', style: TextStyle(color: AppTheme.slate500, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Category Selector Header
            const Text('Services Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
            const SizedBox(height: 14),

            // 4. Categories Grid
            categoriesAsync.when(
              data: (categories) => _buildCategoryGrid(categories),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildFallbackCategoryGrid(),
            ),
            const SizedBox(height: 28),

            // 5. Featured Services List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Popular Repairs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
                Text('View all', style: TextStyle(fontSize: 13, color: AppTheme.primaryIndigo, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            _buildServiceItemCard(
              ServiceItem(
                id: 's1',
                categoryId: 'c1',
                name: 'Tap & Mixer Leakage Repair',
                description: 'Fix dripping faucets, internal spindle valve replacement',
                minEstimatePaise: 15000,
                maxEstimatePaise: 45000,
                visitingChargePaise: 9900,
                durationMinutes: 45,
                commissionPct: 15.0,
                fixedPlatformFeePaise: 4900,
              ),
            ),
            const SizedBox(height: 12),
            _buildServiceItemCard(
              ServiceItem(
                id: 's2',
                categoryId: 'c1',
                name: 'Drainage & Pipe Unclogging',
                description: 'Pressure unclogging for kitchen sink, bathroom traps',
                minEstimatePaise: 25000,
                maxEstimatePaise: 90000,
                visitingChargePaise: 9900,
                durationMinutes: 60,
                commissionPct: 15.0,
                fixedPlatformFeePaise: 4900,
              ),
            ),
            const SizedBox(height: 12),
            _buildServiceItemCard(
              ServiceItem(
                id: 's3',
                categoryId: 'c4',
                name: 'AC Jet Cleaning & Foam Wash',
                description: 'Deep cooling coil cleaning with high-pressure water pump',
                minEstimatePaise: 49900,
                maxEstimatePaise: 120000,
                visitingChargePaise: 19900,
                durationMinutes: 60,
                commissionPct: 15.0,
                fixedPlatformFeePaise: 4900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBookingCard() {
    final b = _mockActiveBooking!;
    final status = b['status'] as String;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryIndigo.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryIndigo),
                ),
              ),
              // Start OTP pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin, size: 14, color: AppTheme.slate700),
                    const SizedBox(width: 4),
                    Text('Start OTP: ${b['start_otp']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.slate800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(b['service_name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
          const SizedBox(height: 4),
          Text(b['worker_name'] as String, style: const TextStyle(fontSize: 13, color: AppTheme.slate700)),
          const SizedBox(height: 14),

          // Action button depending on status
          if (status == 'IN_PROGRESS' || status == 'AMOUNT_PENDING_APPROVAL')
            ElevatedButton.icon(
              onPressed: _showQuoteSheet,
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Review Post-Work Quote'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: AppTheme.primaryIndigo,
              ),
            )
          else
            Text(b['address'] as String, style: const TextStyle(fontSize: 12, color: AppTheme.slate500)),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<ServiceCategory> categories) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = cat.slug == _selectedCategorySlug;

        return InkWell(
          onTap: () => setState(() => _selectedCategorySlug = cat.slug),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryLight : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.primaryIndigo : AppTheme.slate200,
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_iconForCategory(cat.slug), size: 28, color: isSelected ? AppTheme.primaryIndigo : AppTheme.slate700),
                const SizedBox(height: 8),
                Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryIndigo : AppTheme.slate800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackCategoryGrid() {
    final list = [
      {'name': 'Plumbing', 'slug': 'plumbing'},
      {'name': 'Electrical', 'slug': 'electrical'},
      {'name': 'Carpentry', 'slug': 'carpentry'},
      {'name': 'AC Repair', 'slug': 'ac-repair'},
      {'name': 'Cleaning', 'slug': 'cleaning'},
      {'name': 'Painting', 'slug': 'painting'},
    ];
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final cat = list[index];
        final isSelected = cat['slug'] == _selectedCategorySlug;

        return InkWell(
          onTap: () => setState(() => _selectedCategorySlug = cat['slug']!),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryLight : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.primaryIndigo : AppTheme.slate200,
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_iconForCategory(cat['slug']!), size: 28, color: isSelected ? AppTheme.primaryIndigo : AppTheme.slate700),
                const SizedBox(height: 8),
                Text(
                  cat['name']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryIndigo : AppTheme.slate800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceItemCard(ServiceItem service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(service.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Visit: ${service.visitingChargeRupees}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.slate700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(service.description, style: const TextStyle(fontSize: 12.5, color: AppTheme.slate500)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(service.estimateRangeRupees, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slate900)),
              ElevatedButton(
                onPressed: () => _openBookingSheet(service),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Book', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoPill(String title, String val) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.slate500)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slate800)),
      ],
    );
  }

  IconData _iconForCategory(String slug) {
    switch (slug) {
      case 'plumbing':
        return Icons.plumbing_rounded;
      case 'electrical':
        return Icons.bolt_rounded;
      case 'carpentry':
        return Icons.handyman_rounded;
      case 'ac-repair':
        return Icons.ac_unit_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'painting':
        return Icons.format_paint_rounded;
      default:
        return Icons.build_rounded;
    }
  }
}
