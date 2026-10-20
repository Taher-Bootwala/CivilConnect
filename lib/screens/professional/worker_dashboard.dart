// CivilHand Service Professional Dashboard
// Financial dues monitoring, ₹5,000 cash limit guard, and job workflow with swipe sliders

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/swipe_slider.dart';
import 'kyc_submission_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  final VoidCallback? onSignOut;
  final String? workerName;
  final String? workerTrade;

  const WorkerDashboardScreen({
    super.key,
    this.onSignOut,
    this.workerName,
    this.workerTrade,
  });

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}


class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  bool _isOnline = true;
  int _platformDuesPaise = 245000; // ₹2,450 owed to platform
  final int _cashLimitPaise = 500000; // ₹5,000 limit

  // Mock Active Job state machine
  String _jobStatus = 'ARRIVED'; // 'ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS', 'WORK_DONE'
  final String _bookingCode = 'CH-PLUMB-921';
  final String _serviceName = 'Tap & Mixer Leakage Repair';
  final String _customerAddress = 'Flat 402, Shivalik Heights, CG Road';
  final String _customerName = 'Amit Shah';

  void _openStartOtpDialog() {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Customer Start OTP', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ask the customer for the 4-digit security code displayed on their app.',
              style: TextStyle(fontSize: 13, color: AppTheme.slate500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppTheme.slate100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final otp = otpController.text.trim();
              if (otp.length == 4) {
                Navigator.pop(ctx);
                setState(() {
                  _jobStatus = 'IN_PROGRESS';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: AppTheme.successGreen, content: Text('OTP Verified! Work session started.')),
                );
              }
            },
            child: const Text('Verify & Start'),
          ),
        ],
      ),
    );
  }

  void _openQuoteBuilderDialog() {
    final laborController = TextEditingController(text: '450');
    final materialController = TextEditingController(text: '180');
    final noteController = TextEditingController(text: 'Replaced internal brass spindle valve.');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final labor = int.tryParse(laborController.text) ?? 0;
          final material = int.tryParse(materialController.text) ?? 0;
          const visiting = 99;
          const platformFee = 49;
          final commission = ((labor + visiting) * 0.15).round();
          final totalCustomer = labor + material + visiting + platformFee;
          final netLabor = (labor + material + visiting) - commission;

          return Container(
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
                const SizedBox(height: 16),
                const Text('Generate Final Job Quote', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const Text('Enter itemized work charges for customer approval', style: TextStyle(fontSize: 13, color: AppTheme.slate500)),
                const SizedBox(height: 16),

                TextField(
                  controller: laborController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Labor Charges (₹)',
                    filled: true,
                    fillColor: AppTheme.slate100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: materialController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Materials / Parts Cost (₹) (0% Commission)',
                    filled: true,
                    fillColor: AppTheme.slate100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Work explanation note',
                    filled: true,
                    fillColor: AppTheme.slate100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // Real-time Earnings Calculation Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.slate50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.slate200),
                  ),
                  child: Column(
                    children: [
                      _calcRow('Customer Total', '₹$totalCustomer', isBold: true),
                      const SizedBox(height: 4),
                      _calcRow('Visiting Charge', '₹$visiting'),
                      _calcRow('Platform Commission (15%)', '- ₹$commission'),
                      _calcRow('Customer Platform Fee', '₹$platformFee'),
                      const Divider(color: AppTheme.slate200, height: 16),
                      _calcRow('Your Net Earnings', '₹$netLabor', isBold: true, color: AppTheme.successGreen),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _jobStatus = 'AMOUNT_PENDING_APPROVAL';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: AppTheme.primaryIndigo, content: Text('Quote submitted to customer for approval.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppTheme.primaryIndigo,
                  ),
                  child: const Text('Send Quote to Customer', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _settleDuesViaRazorpay() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Settle Platform Dues', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remit outstanding commission of ₹${(_platformDuesPaise / 100).toStringAsFixed(0)} via Razorpay (UPI / NetBanking)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _platformDuesPaise = 0; // Settled
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: AppTheme.successGreen, content: Text('Dues settled successfully via Razorpay!')),
              );
            },
            child: const Text('Pay via Razorpay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duesRupees = (_platformDuesPaise / 100).toStringAsFixed(0);
    final limitRupees = (_cashLimitPaise / 100).toStringAsFixed(0);
    final double exposureRatio = (_platformDuesPaise / _cashLimitPaise).clamp(0.0, 1.0);
    final isWarning = exposureRatio >= 0.8;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.workerName != null ? widget.workerName! : 'Professional Console',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.workerTrade != null ? '${widget.workerTrade!} • CivilHand Partner' : 'Partner Console',
              style: const TextStyle(fontSize: 11, color: AppTheme.slate500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge_outlined, color: AppTheme.primaryIndigo),
            tooltip: 'Submit KYC & Bank Details',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KycSubmissionScreen()),
              );
            },
          ),
          Row(
            children: [
              Text(_isOnline ? 'ON' : 'OFF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _isOnline ? AppTheme.successGreen : AppTheme.slate500)),
              Switch(
                value: _isOnline,
                activeColor: AppTheme.successGreen,
                onChanged: (val) => setState(() => _isOnline = val),
              ),
            ],
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
                    content: const Text('Are you sure you want to sign out of your professional account?'),
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
          const SizedBox(width: 4),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cash Exposure & ₹5,000 Limit Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isWarning ? AppTheme.warningAmber : AppTheme.slate200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Outstanding Platform Dues', style: TextStyle(fontSize: 13, color: AppTheme.slate500, fontWeight: FontWeight.w600)),
                      if (isWarning)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.warningAmber.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Near Limit (80%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.warningAmber)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹$duesRupees', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.slate900)),
                      Text('Limit: ₹$limitRupees', style: const TextStyle(fontSize: 13, color: AppTheme.slate500)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: exposureRatio,
                      minHeight: 8,
                      backgroundColor: AppTheme.slate100,
                      valueColor: AlwaysStoppedAnimation<Color>(isWarning ? AppTheme.warningAmber : AppTheme.primaryIndigo),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _settleDuesViaRazorpay,
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Settle Platform Dues via Razorpay'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      foregroundColor: AppTheme.primaryIndigo,
                      side: const BorderSide(color: AppTheme.primaryIndigo),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Active Job Management Section
            const Text('Active Assigned Job', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_bookingCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slate500)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          _jobStatus.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryIndigo),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_serviceName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_pin, size: 16, color: AppTheme.slate500),
                      const SizedBox(width: 4),
                      Text('Customer: $_customerName', style: const TextStyle(fontSize: 13.5, color: AppTheme.slate700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.slate500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(_customerAddress, style: const TextStyle(fontSize: 12.5, color: AppTheme.slate500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Dynamic Action Sliders Based on State Machine
                  if (_jobStatus == 'ACCEPTED')
                    SwipeToConfirmSlider(
                      label: 'Slide: On the Way',
                      icon: Icons.navigation_rounded,
                      activeColor: AppTheme.accentTeal,
                      onConfirmed: () async {
                        await Future.delayed(const Duration(milliseconds: 300));
                        setState(() => _jobStatus = 'ON_THE_WAY');
                      },
                    )
                  else if (_jobStatus == 'ON_THE_WAY')
                    SwipeToConfirmSlider(
                      label: 'Slide: Verify Geofence Arrival',
                      icon: Icons.pin_drop_rounded,
                      activeColor: AppTheme.accentTeal,
                      onConfirmed: () async {
                        await Future.delayed(const Duration(milliseconds: 300));
                        setState(() => _jobStatus = 'ARRIVED');
                      },
                    )
                  else if (_jobStatus == 'ARRIVED') ...[
                    SwipeToConfirmSlider(
                      label: 'Slide: Enter Customer OTP & Start',
                      icon: Icons.lock_open_rounded,
                      activeColor: AppTheme.primaryIndigo,
                      onConfirmed: () async {
                        _openStartOtpDialog();
                      },
                    ),
                  ] else if (_jobStatus == 'IN_PROGRESS') ...[
                    ElevatedButton.icon(
                      onPressed: _openQuoteBuilderDialog,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Complete Work & Submit Quote'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    ),
                  ] else if (_jobStatus == 'AMOUNT_PENDING_APPROVAL') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppTheme.slate50, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: const [
                          Icon(Icons.hourglass_top_rounded, color: AppTheme.warningAmber),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Quote sent! Waiting for customer to approve or raise dispute.',
                              style: TextStyle(fontSize: 13, color: AppTheme.slate700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calcRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400, color: AppTheme.slate700)),
        Text(value, style: TextStyle(fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: color ?? AppTheme.slate900)),
      ],
    );
  }
}
