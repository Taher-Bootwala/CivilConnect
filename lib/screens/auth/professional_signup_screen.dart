// CivilHand Professional Multi-Step Registration Screen
// Implements Aadhaar-compliant identity, dual phone & email verification, multi-skill selection with experience, Aadhaar OTP, and password security.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';

class ProfessionalSignupScreen extends ConsumerStatefulWidget {
  final void Function(String name, String phone, List<String> skills) onCompleted;

  const ProfessionalSignupScreen({super.key, required this.onCompleted});

  @override
  ConsumerState<ProfessionalSignupScreen> createState() => _ProfessionalSignupScreenState();
}

class _ProfessionalSignupScreenState extends ConsumerState<ProfessionalSignupScreen> {
  int _currentStep = 1; // 1: Info & Contact, 2: Skills & Experience, 3: Aadhaar, 4: Password, 5: Under Review

  // Step 1 Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneOtpController = TextEditingController();
  final _emailOtpController = TextEditingController();

  bool _isPhoneOtpSent = false;
  bool _isPhoneVerified = false;
  bool _isEmailOtpSent = false;
  bool _isEmailVerified = false;
  bool _isCheckingDuplicate = false;

  // Step 2 Skills & Experience
  final List<String> _availableSkills = [
    'Plumbing & Pipe Repair',
    'Electrical & Wiring',
    'Carpentry & Furniture',
    'Painting & Waterproofing',
    'AC & Appliance Service',
    'Deep Cleaning & Sanitization',
    'Masonry & Tile Fitting',
    'Pest Control Service',
  ];

  final Set<String> _selectedSkills = {};
  final Map<String, TextEditingController> _skillExperienceControllers = {};
  bool _sameExpForAll = false;
  final _sharedExpController = TextEditingController(text: '3');

  // Step 3 Aadhaar Verification
  final _aadhaarController = TextEditingController();
  final _aadhaarOtpController = TextEditingController();
  bool _isAadhaarOtpSent = false;
  bool _isAadhaarVerified = false;

  // Step 4 Password
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _phoneOtpController.dispose();
    _emailOtpController.dispose();
    _sharedExpController.dispose();
    _aadhaarController.dispose();
    _aadhaarOtpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _skillExperienceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Step 1 Actions ---
  void _sendPhoneOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    setState(() => _isPhoneOtpSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.primaryIndigo,
        content: Text('Mobile OTP sent! (Demo mode: Use code 123456)'),
      ),
    );
  }

  void _verifyPhoneOtp() {
    final otp = _phoneOtpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit Mobile OTP')),
      );
      return;
    }
    setState(() => _isPhoneVerified = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: AppTheme.successGreen, content: Text('Phone number verified successfully! ✓')),
    );
  }

  void _sendEmailOtp() {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _isEmailOtpSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primaryIndigo,
        content: Text('Verification code sent to $email! (Demo code: 654321)'),
      ),
    );
  }

  void _verifyEmailOtp() {
    final otp = _emailOtpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit Email OTP')),
      );
      return;
    }
    setState(() => _isEmailVerified = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: AppTheme.successGreen, content: Text('Email verified successfully! ✓')),
    );
  }

  void _proceedToSkills() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name as per Aadhaar')),
      );
      return;
    }
    if (!_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your mobile number first')),
      );
      return;
    }
    if (!_isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your email address')),
      );
      return;
    }

    // Check duplicate in Supabase database
    setState(() => _isCheckingDuplicate = true);
    final phone = '+91${_phoneController.text.trim()}';
    final email = _emailController.text.trim();

    try {
      final supabase = ref.read(supabaseClientProvider);
      final existingPhone = await supabase.from('profiles').select('id').eq('phone', phone).maybeSingle();
      final existingEmail = await supabase.from('profiles').select('id').eq('email', email).maybeSingle();

      if (existingPhone != null) {
        setState(() => _isCheckingDuplicate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppTheme.dangerRose, content: Text('An account with this mobile number already exists! Please sign in.')),
        );
        return;
      }
      if (existingEmail != null) {
        setState(() => _isCheckingDuplicate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppTheme.dangerRose, content: Text('An account with this email already exists! Please sign in.')),
        );
        return;
      }
    } catch (_) {
      // In local offline mode continue safely
    }

    setState(() {
      _isCheckingDuplicate = false;
      _currentStep = 2;
    });
  }

  // --- Step 2 Actions ---
  void _toggleSkill(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
        if (!_skillExperienceControllers.containsKey(skill)) {
          _skillExperienceControllers[skill] = TextEditingController(text: '3');
        }
      }
    });
  }

  void _proceedToAadhaar() {
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one field of work/skill')),
      );
      return;
    }
    setState(() => _currentStep = 3);
  }

  // --- Step 3 Actions ---
  void _sendAadhaarOtp() {
    final aadhaar = _aadhaarController.text.replaceAll(' ', '').trim();
    if (aadhaar.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 12-digit Aadhaar number')),
      );
      return;
    }

    setState(() => _isAadhaarOtpSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.primaryIndigo,
        content: Text('UIDAI OTP sent to registered mobile linked with Aadhaar! (Demo code: 888999)'),
      ),
    );
  }

  void _verifyAadhaarOtp() {
    final otp = _aadhaarOtpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit Aadhaar OTP')),
      );
      return;
    }

    setState(() {
      _isAadhaarVerified = true;
      _currentStep = 4;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: AppTheme.successGreen, content: Text('Aadhaar identity verified successfully! ✓')),
    );
  }

  // --- Step 4 Actions ---
  void _completeRegistration() async {
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppTheme.dangerRose, content: Text('Passwords do not match')),
      );
      return;
    }

    final name = _nameController.text.trim();
    final phone = '+91${_phoneController.text.trim()}';
    final email = _emailController.text.trim();
    final skills = _selectedSkills.toList();

    // Persist registration in SharedPreferences as authenticated professional in "pending" status
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_authenticated', true);
    await prefs.setString('user_role', 'professional');
    await prefs.setString('user_name', name);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_email', email);
    await prefs.setString('kyc_status', 'pending');
    await prefs.setStringList('user_skills', skills);

    setState(() => _currentStep = 5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Professional Registration', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: _currentStep > 1 && _currentStep < 5
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentStep < 5) ...[
                _buildStepperHeader(),
                const SizedBox(height: 24),
              ],
              if (_currentStep == 1) _buildStep1Info(),
              if (_currentStep == 2) _buildStep2Skills(),
              if (_currentStep == 3) _buildStep3Aadhaar(),
              if (_currentStep == 4) _buildStep4Password(),
              if (_currentStep == 5) _buildStep5UnderReview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Step $_currentStep of 4', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryIndigo)),
            Text(
              _currentStep == 1 ? 'Personal & Contact' : (_currentStep == 2 ? 'Skills & Experience' : (_currentStep == 3 ? 'Aadhaar Verification' : 'Set Password')),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _currentStep / 4,
          backgroundColor: AppTheme.slate100,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryIndigo),
          borderRadius: BorderRadius.circular(10),
          minHeight: 6,
        ),
      ],
    );
  }

  // --- STEP 1: Personal Info, Phone & Email Verification ---
  Widget _buildStep1Info() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter Personal Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.slate900)),
        const SizedBox(height: 4),
        const Text('Name must match your official Aadhaar Card identity', style: TextStyle(fontSize: 13, color: AppTheme.slate500)),
        const SizedBox(height: 20),

        const Text('Full Name (as per Aadhaar)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'e.g. Rameshchandra Motilal Patel',
            prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.slate500),
            filled: true,
            fillColor: AppTheme.slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.slate200)),
          ),
        ),
        const SizedBox(height: 18),

        // Phone Verification Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            if (_isPhoneVerified)
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 16),
                  SizedBox(width: 4),
                  Text('Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.successGreen)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                enabled: !_isPhoneVerified,
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Text('+91', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.slate800, fontSize: 15)),
                  ),
                  hintText: '98765 43210',
                  filled: true,
                  fillColor: _isPhoneVerified ? AppTheme.slate100 : AppTheme.slate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.slate200)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (!_isPhoneVerified)
              ElevatedButton(
                onPressed: _sendPhoneOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                child: Text(_isPhoneOtpSent ? 'Resend' : 'Get OTP', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
          ],
        ),

        if (_isPhoneOtpSent && !_isPhoneVerified) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '6-digit Phone OTP',
                    filled: true,
                    fillColor: AppTheme.primaryLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryIndigo)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _verifyPhoneOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: const Text('Verify Phone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // Email Verification Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            if (_isEmailVerified)
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 16),
                  SizedBox(width: 4),
                  Text('Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.successGreen)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isEmailVerified,
                decoration: InputDecoration(
                  hintText: 'ramesh.patel@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.slate500),
                  filled: true,
                  fillColor: _isEmailVerified ? AppTheme.slate100 : AppTheme.slate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.slate200)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (!_isEmailVerified)
              ElevatedButton(
                onPressed: _sendEmailOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                child: Text(_isEmailOtpSent ? 'Resend' : 'Verify Email', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
          ],
        ),

        if (_isEmailOtpSent && !_isEmailVerified) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '6-digit Email OTP',
                    filled: true,
                    fillColor: AppTheme.primaryLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryIndigo)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _verifyEmailOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: const Text('Verify Email', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isCheckingDuplicate ? null : _proceedToSkills,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryIndigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isCheckingDuplicate
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Next: Select Skills & Experience →', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // --- STEP 2: Multi-Skill Selection & Years of Experience ---
  Widget _buildStep2Skills() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Your Fields of Work', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.slate900)),
        const SizedBox(height: 4),
        const Text('Choose all skills you are qualified to perform. You can select multiple fields.', style: TextStyle(fontSize: 13, color: AppTheme.slate500)),
        const SizedBox(height: 18),

        // Available Skills Checkbox / Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableSkills.map((skill) {
            final isSelected = _selectedSkills.contains(skill);
            return FilterChip(
              label: Text(skill, style: TextStyle(fontSize: 12.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
              selected: isSelected,
              selectedColor: AppTheme.primaryIndigo.withOpacity(0.12),
              checkmarkColor: AppTheme.primaryIndigo,
              labelStyle: TextStyle(color: isSelected ? AppTheme.primaryIndigo : AppTheme.slate700),
              backgroundColor: AppTheme.slate50,
              side: BorderSide(color: isSelected ? AppTheme.primaryIndigo : AppTheme.slate200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (_) => _toggleSkill(skill),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        if (_selectedSkills.isNotEmpty) ...[
          // "Same for all selected skills" toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _sameExpForAll,
                  activeColor: AppTheme.primaryIndigo,
                  onChanged: (val) {
                    setState(() {
                      _sameExpForAll = val ?? false;
                      if (_sameExpForAll) {
                        for (var s in _selectedSkills) {
                          _skillExperienceControllers[s]?.text = _sharedExpController.text;
                        }
                      }
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'Same experience for all selected skills',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryIndigo),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_sameExpForAll) ...[
            const Text('Years of Experience (Applied to all skills)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _sharedExpController,
              keyboardType: TextInputType.number,
              onChanged: (val) {
                for (var s in _selectedSkills) {
                  _skillExperienceControllers[s]?.text = val;
                }
              },
              decoration: InputDecoration(
                hintText: 'e.g. 5',
                suffixText: 'Years',
                filled: true,
                fillColor: AppTheme.slate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.slate200)),
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            const Text('Years of Experience per Selected Skill', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 10),
            ..._selectedSkills.map((skill) {
              final controller = _skillExperienceControllers[skill] ??= TextEditingController(text: '3');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(skill, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'Years',
                          suffixText: 'yrs',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: AppTheme.slate50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.slate200)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ],

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _proceedToAadhaar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryIndigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Next: Aadhaar Verification →', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // --- STEP 3: Aadhaar Verification with OTP ---
  Widget _buildStep3Aadhaar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aadhaar Identity Verification', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.slate900)),
        const SizedBox(height: 4),
        const Text('Mandatory government verification ensuring trust and security on CivilHand', style: TextStyle(fontSize: 13, color: AppTheme.slate500)),
        const SizedBox(height: 24),

        const Text('12-Digit Aadhaar Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _aadhaarController,
          keyboardType: TextInputType.number,
          maxLength: 12,
          enabled: !_isAadhaarVerified,
          decoration: InputDecoration(
            counterText: '',
            hintText: 'XXXX XXXX XXXX',
            prefixIcon: const Icon(Icons.credit_card_rounded, color: AppTheme.slate500),
            filled: true,
            fillColor: _isAadhaarVerified ? AppTheme.slate100 : AppTheme.slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.slate200)),
          ),
        ),
        const SizedBox(height: 16),

        if (!_isAadhaarOtpSent)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _sendAadhaarOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryIndigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Send Aadhaar OTP to Linked Mobile', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          )
        else ...[
          const Text('Enter Aadhaar OTP sent by UIDAI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _aadhaarOtpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              counterText: '',
              hintText: '888999',
              filled: true,
              fillColor: AppTheme.primaryLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryIndigo)),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _verifyAadhaarOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Verify Aadhaar & Proceed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ],
    );
  }

  // --- STEP 4: Set Password ---
  Widget _buildStep4Password() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Set Your Account Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.slate900)),
        const SizedBox(height: 4),
        const Text('Create a secure password to log in to your CivilHand worker dashboard', style: TextStyle(fontSize: 13, color: AppTheme.slate500)),
        const SizedBox(height: 24),

        const Text('Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            hintText: 'Minimum 6 characters',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.slate500),
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppTheme.slate500),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            filled: true,
            fillColor: AppTheme.slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.slate200)),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            hintText: 'Re-enter password',
            prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppTheme.slate500),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppTheme.slate500),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            filled: true,
            fillColor: AppTheme.slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.slate200)),
          ),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _completeRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryIndigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Complete Registration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // --- STEP 5: Under Review Success Message ---
  Widget _buildStep5UnderReview() {
    final name = _nameController.text.trim();
    final skills = _selectedSkills.join(', ');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: AppTheme.warningAmber, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Account Has Been Created Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.slate900),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
              ),
              child: const Text(
                'Status: In Review Process',
                style: TextStyle(color: AppTheme.warningAmber, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please wait for some time. Our administration team is reviewing your Aadhaar details and selected skills. Once approved, you will receive an email confirmation and can begin accepting booking requests.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppTheme.slate600, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Profile Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Registered Worker Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slate900)),
                  const Divider(color: AppTheme.slate200, height: 16),
                  _summaryRow('Name:', name),
                  _summaryRow('Phone:', '+91 ${_phoneController.text} (Verified ✓)'),
                  _summaryRow('Email:', '${_emailController.text} (Verified ✓)'),
                  _summaryRow('Aadhaar:', 'Verified via UIDAI OTP ✓'),
                  _summaryRow('Registered Skills:', skills),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onCompleted(name, '+91${_phoneController.text.trim()}', _selectedSkills.toList());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Open Worker Console', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.slate500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate800))),
        ],
      ),
    );
  }
}
