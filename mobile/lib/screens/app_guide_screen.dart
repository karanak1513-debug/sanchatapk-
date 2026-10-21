import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/brand_logo.dart';

/// Interactive Visual App Guide & Simulation Deck for Sanchay
/// Replaces static text with a 4-slide interactive simulation experience:
/// 1. Autonomous Background Interceptor (Live +₹500 notification simulation)
/// 2. Dual Ledger Isolation (Interactive Liquid Cash vs Protected Vault)
/// 3. Sanchay Connect (Interactive mock chat with tap-to-split payment)
/// 4. Biometric Shield (Interactive AES-256 local database encryption unlock)
class AppGuideScreen extends StatefulWidget {
  const AppGuideScreen({super.key});

  @override
  State<AppGuideScreen> createState() => _AppGuideScreenState();
}

class _AppGuideScreenState extends State<AppGuideScreen> {
  final PageController _pageController = PageController();
  int _currentSlide = 0;

  // Slide 1 State: Autonomous Background Interceptor
  bool _s1Intercepted = false;
  double _s1LiquidRunway = 14250.0;

  // Slide 2 State: Dual Ledger Isolation
  static const double _s2VaultCap = 100000.0;
  static const double _s2LiquidCash = 14750.0;
  double _s2VaultAmount = 30000.0;
  double _s2DaysRemaining = 35.0;

  // Slide 3 State: Sanchay Connect Split
  bool _s3SplitCompleted = false;

  // Slide 4 State: Biometric Shield
  bool _s4VaultUnlocked = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (_currentSlide < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevSlide() {
    if (_currentSlide > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Back to Dashboard',
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const SanchatBrandLogo(size: 26),
            const SizedBox(width: 10),
            Text(
              'Sanchat Guide',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_currentSlide + 1} / 4',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Slide Title & Progress Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: List.generate(4, (index) {
                  final isActive = index == _currentSlide;
                  final isDone = index < _currentSlide;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF059669)
                            : isDone
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // PageView Slider Deck
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentSlide = idx),
                children: [
                  _buildSlide1AutonomousInterceptor(),
                  _buildSlide2DualLedger(),
                  _buildSlide3SanchayConnect(),
                  _buildSlide4BiometricShield(),
                ],
              ),
            ),

            // Bottom Navigation Dock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentSlide > 0)
                    TextButton.icon(
                      onPressed: _prevSlide,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Previous'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    )
                  else
                    const SizedBox(width: 80),

                  // Dots Indicator
                  Row(
                    children: List.generate(4, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _currentSlide ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: i == _currentSlide
                              ? const Color(0xFF059669)
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),

                  if (_currentSlide < 3)
                    ElevatedButton.icon(
                      onPressed: _nextSlide,
                      icon: const Text('Next'),
                      label: const Icon(Icons.arrow_forward_rounded, size: 16),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      child: const Text('Got It! 🚀'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SLIDE 1: AUTONOMOUS BACKGROUND INTERCEPTOR
  // ===========================================================================
  Widget _buildSlide1AutonomousInterceptor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBadge(
            category: 'ENGINE 01',
            title: 'Autonomous Background Interceptor',
            subtitle: 'Real-time on-device payment detection with zero manual typing.',
          ),
          const SizedBox(height: 18),

          // Interactive Simulation Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SIMULATED NOTIFICATION',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE REGEX',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Simulated Phone Notification Card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _s1Intercepted
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _s1Intercepted
                          ? const Color(0xFF10B981).withOpacity(0.4)
                          : const Color(0xFFCBD5E1),
                      width: _s1Intercepted ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5F259F), // PhonePe violet
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PhonePe • UPI Notification',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  'Just now',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'SUBODH PRASAD paid you ₹500.00',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Interactive Trigger Button
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      if (!_s1Intercepted) {
                        _s1Intercepted = true;
                        _s1LiquidRunway += 500.0;
                      } else {
                        _s1Intercepted = false;
                        _s1LiquidRunway -= 500.0;
                      }
                    });
                  },
                  icon: Icon(
                    _s1Intercepted ? Icons.refresh_rounded : Icons.flash_on_rounded,
                    size: 18,
                  ),
                  label: Text(_s1Intercepted
                      ? 'Reset Simulation'
                      : 'Simulate Payment Notification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _s1Intercepted
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 18),

                // Live Liquid Runway Impact Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NET CASH LIQUIDITY',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _s1Intercepted
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF0F172A),
                            ),
                            child: Text('₹${_s1LiquidRunway.toStringAsFixed(0)}'),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _s1Intercepted
                              ? const Color(0xFF10B981).withOpacity(0.18)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _s1Intercepted ? '+₹500.00 CREDITED ✓' : 'Awaiting Notification',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _s1Intercepted
                                ? const Color(0xFF047857)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _buildProTip(
            'Polarity Guarantee: "paid you" is recognized exclusively as income inflow. Sanchat will NEVER count received money as an expense.',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SLIDE 2: DUAL LEDGER & INTERACTIVE VAULT PACING SLIDER
  // ===========================================================================
  Widget _buildSlide2DualLedger() {
    final progress = (_s2VaultAmount / _s2VaultCap).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final remainingAmount = (_s2VaultCap - _s2VaultAmount).clamp(0.0, _s2VaultCap);
    final days = _s2DaysRemaining > 0 ? _s2DaysRemaining : 1.0;
    final dailyPace = remainingAmount / days;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBadge(
            category: 'ENGINE 02',
            title: 'Interactive Vault & Daily Pacing',
            subtitle: 'Vault savings are protected reserves. Test live daily pacing formulas dynamically.',
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ledger Comparison Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TAB 1: LIQUID FEED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF059669),
                      ),
                    ),
                    Text(
                      'TAB 2: VAULT JOURNAL',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vault Card Visual
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.flight_takeoff_rounded,
                                    color: Color(0xFF2563EB), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Goa Vacation Vault',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$pct% Paced',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Progress Bar
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${_s2VaultAmount.toStringAsFixed(0)} of ₹${_s2VaultCap.toStringAsFixed(0)}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '₹${remainingAmount.toStringAsFixed(0)} Remaining',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Interactive Vault Slider & Daily Pacing Formula Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DAILY PACING ENGINE',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '₹${dailyPace.toStringAsFixed(0)} / Day Target',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Formula: (₹${_s2VaultCap.toInt()} Cap - ₹${_s2VaultAmount.toInt()} Saved) ÷ ${days.toInt()} Days = ₹${dailyPace.toStringAsFixed(0)} / Day',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Slider 1: Vault Saved Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Adjust Saved Amount:',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                          Text(
                            '₹${_s2VaultAmount.toInt()}',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: _s2VaultAmount,
                          min: 0.0,
                          max: _s2VaultCap,
                          divisions: 20,
                          activeColor: const Color(0xFF10B981),
                          inactiveColor: const Color(0xFFCBD5E1),
                          onChanged: (val) => setState(() => _s2VaultAmount = val),
                        ),
                      ),

                      // Slider 2: Days to Deadline
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Adjust Days to Target Deadline:',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                          Text(
                            '${days.toInt()} Days',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: _s2DaysRemaining,
                          min: 5.0,
                          max: 90.0,
                          divisions: 17,
                          activeColor: const Color(0xFF2563EB),
                          inactiveColor: const Color(0xFFCBD5E1),
                          onChanged: (val) => setState(() => _s2DaysRemaining = val),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Net Worth Invariance Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: Color(0xFF059669), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total Net Worth = ₹${(_s2LiquidCash + _s2VaultAmount).toStringAsFixed(0)} (100% Intact). Sanchat keeps savings and expenses strictly isolated.',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _buildProTip(
            'Zero Cloud Leak: Vault allocations happen inside an atomic Firestore batch transaction, keeping your goal progress and transaction history perfectly aligned.',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SLIDE 3: SANCHAT CONNECT (PEER CHAT & P2P EXPENSE SPLIT)
  // ===========================================================================
  Widget _buildSlide3SanchayConnect() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBadge(
            category: 'ENGINE 03',
            title: 'Sanchat Connect & P2P Split',
            subtitle: 'Secure 1-on-1 financial peer messaging with mutual friend gating and instant bill split triggers.',
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chat Header Preview
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF0F172A),
                      child: Text(
                        'RS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rahul Sharma',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '@rahul_s • Mutual Friend on Sanchat ✓',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF059669),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mock Chat Bubble & Bill Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dinner bill at Toit! 🍽️',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹1,200.00 Total',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Split 50/50 between 2 members (₹600 each)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Interactive Tap-to-Split Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _s3SplitCompleted = !_s3SplitCompleted);
                          },
                          icon: Icon(
                            _s3SplitCompleted
                                ? Icons.check_circle_rounded
                                : Icons.call_split_rounded,
                            size: 16,
                          ),
                          label: Text(_s3SplitCompleted
                              ? 'P2P Split Triggered via Sanchat ✓ (₹600)'
                              : '⚡ Trigger Sanchat P2P Split (₹600)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _s3SplitCompleted
                                ? const Color(0xFF059669)
                                : const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            textStyle: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Hard Delete Explanation Badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep_rounded,
                          color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Delete for Everyone: Physically purges messages from the cloud with zero ghost remnants.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _buildProTip(
            'Anti-Spam Gate: Strangers cannot message you unless both parties accept friend requests under friend_requests/',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SLIDE 4: BIOMETRIC SHIELD (AES-256 SOVEREIGNTY)
  // ===========================================================================
  Widget _buildSlide4BiometricShield() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBadge(
            category: 'SECURITY 04',
            title: 'Biometric Shield',
            subtitle: 'Hardware enclave biometric sovereignty and AES-256 local encryption.',
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Animated Biometric Insignia
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: _s4VaultUnlocked
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFF0F172A).withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _s4VaultUnlocked
                            ? const Color(0xFF059669)
                            : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _s4VaultUnlocked
                          ? Icons.lock_open_rounded
                          : Icons.fingerprint_rounded,
                      size: 38,
                      color: _s4VaultUnlocked
                          ? const Color(0xFF059669)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Center(
                  child: Text(
                    _s4VaultUnlocked
                        ? 'VAULT DECRYPTED & MOUNTED'
                        : 'LOCAL DATABASE ENCRYPTED (AES-256)',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _s4VaultUnlocked
                          ? const Color(0xFF059669)
                          : const Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Interactive Sensor Button
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _s4VaultUnlocked = !_s4VaultUnlocked);
                  },
                  icon: Icon(
                    _s4VaultUnlocked ? Icons.lock_outline : Icons.fingerprint_rounded,
                    size: 18,
                  ),
                  label: Text(_s4VaultUnlocked
                      ? 'Lock Master Vault'
                      : 'Simulate Biometric Fingerprint Unlock 🔐'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _s4VaultUnlocked
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),

                // Encryption Details
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildSecurityRow(
                        'On-Device Storage',
                        'SQLCipher AES-256 Local DB',
                        Icons.storage_rounded,
                      ),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildSecurityRow(
                        'Zero Cloud Overhead',
                        'No Banking Logins / Passwords Stored',
                        Icons.cloud_off_rounded,
                      ),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildSecurityRow(
                        'Biometric Sovereignty',
                        'Bypassed When Disabled by User',
                        Icons.verified_user_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _buildProTip(
            'Sovereignty Guarantee: If Biometric Lock is disabled in Settings, Sanchat will NEVER prompt you or lock you out on app-resume.',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================
  Widget _buildHeaderBadge({
    required String category,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            category,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF059669),
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildProTip(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF334155),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF059669)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
