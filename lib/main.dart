// CivilHand Mobile & Web Application
// Unified role-based experience: Customer, Professional, and Admin

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'screens/customer/home_screen.dart';
import 'screens/professional/worker_dashboard.dart';
import 'screens/auth/phone_auth_screen.dart';
import 'screens/professional/kyc_submission_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/customer/rating_review_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConstants.supabaseUrl.contains('supabase.co') && !AppConstants.supabaseUrl.contains('placeholder')) {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
    } catch (_) {}
  }
  runApp(const ProviderScope(child: CivilHandApp()));
}

class CivilHandApp extends StatefulWidget {
  final bool? initialAuthenticated;
  final String? initialRole;

  const CivilHandApp({
    super.key,
    this.initialAuthenticated,
    this.initialRole,
  });

  @override
  State<CivilHandApp> createState() => _CivilHandAppState();
}

class _CivilHandAppState extends State<CivilHandApp> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String _userRole = 'customer';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    if (widget.initialAuthenticated != null) {
      setState(() {
        _isAuthenticated = widget.initialAuthenticated!;
        _userRole = widget.initialRole ?? 'customer';
        _isLoading = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuth = prefs.getBool('is_authenticated') ?? false;
      final role = prefs.getString('user_role') ?? 'customer';
      final name = prefs.getString('user_name') ?? '';

      setState(() {
        _isAuthenticated = isAuth;
        _userRole = role;
        _userName = name;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  void _handleAuthenticated(String role, String name, String phone) {
    setState(() {
      _isAuthenticated = true;
      _userRole = role;
      _userName = name;
    });
  }

  void _handleSignOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      _isAuthenticated = false;
      _userRole = 'customer';
      _userName = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CivilHand',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _isLoading
          ? const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
              ),
            )
          : (!_isAuthenticated
              ? PhoneAuthScreen(onAuthenticated: _handleAuthenticated)
              : MainRoleShell(
                  userRole: _userRole,
                  userName: _userName,
                  onSignOut: _handleSignOut,
                )),
    );
  }
}

class MainRoleShell extends StatefulWidget {
  final String userRole;
  final String userName;
  final VoidCallback onSignOut;

  const MainRoleShell({
    super.key,
    this.userRole = 'customer',
    this.userName = '',
    required this.onSignOut,
  });

  @override
  State<MainRoleShell> createState() => _MainRoleShellState();
}

class _MainRoleShellState extends State<MainRoleShell> {
  late int _currentTabIndex;

  @override
  void initState() {
    super.initState();
    // Default to Worker Console tab if professional, else Customer App tab
    _currentTabIndex = widget.userRole == 'professional' ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CustomerHomeScreen(
        userName: widget.userName,
        onSignOut: widget.onSignOut,
      ),
      WorkerDashboardScreen(
        workerName: widget.userName,
        workerTrade: widget.userRole == 'professional' ? 'Verified Tradesperson' : null,
        onSignOut: widget.onSignOut,
      ),
      const AdminOverviewScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentTabIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.slate200, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryIndigo,
          unselectedItemColor: AppTheme.slate500,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_repair_service_rounded),
              activeIcon: Icon(Icons.home_repair_service),
              label: 'Customer App',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.engineering_outlined),
              activeIcon: Icon(Icons.engineering_rounded),
              label: 'Worker Console',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Admin & Ledger',
            ),
          ],
        ),
      ),
    );
  }
}


// 3. Admin Overview Screen (Ledger Inspection & KYC Overview)
class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console & Ledger'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            Row(
              children: [
                _kpiCard('Active Jobs', '14', AppTheme.primaryIndigo),
                const SizedBox(width: 12),
                _kpiCard('Pending KYC', '3', AppTheme.warningAmber),
                const SizedBox(width: 12),
                _kpiCard('Platform Dues', '₹24.8K', AppTheme.accentTeal),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Double-Entry Ledger Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
            const SizedBox(height: 12),

            _ledgerTxCard(
              ref: 'TXN-CASH-CH-921',
              type: 'BOOKING_CASH_COLLECTED',
              time: '10 mins ago',
              amount: '₹778.00',
              entries: [
                'DR: 1100 Laborer Cash In Hand (Receivable) +₹114',
                'CR: 4000 Platform Commission (15%) +₹65',
                'CR: 4100 Platform Fixed Fee +₹49',
              ],
            ),
            const SizedBox(height: 12),
            _ledgerTxCard(
              ref: 'TXN-ONLINE-ORD-881',
              type: 'BOOKING_ONLINE_PAYMENT',
              time: '2 hours ago',
              amount: '₹1,249.00',
              entries: [
                'DR: 1000 Razorpay Clearing +₹1,249',
                'CR: 2000 Professional Earnings Payable +₹1,012',
                'CR: 4000 Platform Commission +₹188',
                'CR: 4100 Platform Fixed Fee +₹49',
              ],
            ),
            const SizedBox(height: 24),

            const Text('Pending KYC Applications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppTheme.slate100,
                    child: Icon(Icons.person, color: AppTheme.slate700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Sunil Verma', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text('Electrician • Aadhaar & PAN Submitted', style: TextStyle(fontSize: 12, color: AppTheme.slate500)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: AppTheme.successGreen, content: Text('Sunil Verma approved as Verified Electrician!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 34),
                    ),
                    child: const Text('Approve', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.slate500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  static Widget _ledgerTxCard({
    required String ref,
    required String type,
    required String time,
    required String amount,
    required List<String> entries,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(ref, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
              Text(amount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primaryIndigo)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slate500)),
              Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.slate500)),
            ],
          ),
          const Divider(color: AppTheme.slate200, height: 16),
          ...entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(e, style: const TextStyle(fontSize: 12, color: AppTheme.slate700, fontFamily: 'monospace')),
              )),
        ],
      ),
    );
  }
}
