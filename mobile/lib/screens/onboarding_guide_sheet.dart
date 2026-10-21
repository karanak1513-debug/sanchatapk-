import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sanchay_target.dart';
import '../providers/sanchay_provider.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/center_hud_alert.dart';

/// Interactive 3-Step First-Time User Onboarding Guide Sheet
class OnboardingGuideSheet extends StatefulWidget {
  final bool isForced;

  const OnboardingGuideSheet({super.key, this.isForced = false});

  /// Displays the onboarding walkthrough sheet if the user has not completed it yet.
  /// DISABLED permanently to prevent freezing/trapping users on app launch.
  static Future<void> showIfNeeded(BuildContext context) async {
    return;
  }

  /// Explicitly launch the onboarding walkthrough sheet
  static Future<void> show(BuildContext context, {bool force = true}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => OnboardingGuideSheet(isForced: force),
    );
  }

  @override
  State<OnboardingGuideSheet> createState() => _OnboardingGuideSheetState();
}

class _OnboardingGuideSheetState extends State<OnboardingGuideSheet>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Step 1: Goal state
  double _selectedGoal = 50000.0;
  final List<double> _presetGoals = [25000, 50000, 100000, 200000];

  // Step 2: Auto-tracking radar animation controller
  late AnimationController _radarController;
  bool _isTrackingEnabled = false;

  // Step 3: Handle state
  late TextEditingController _handleController;
  String? _handleError;
  bool _isSavingHandle = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _handleController = TextEditingController();

    // Check tracking status on mount
    _checkPermissionState();

    // Pre-populate handle from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SanchayProvider>();
      if (provider.userHandle.isNotEmpty) {
        _handleController.text = provider.userHandle.replaceAll('@', '');
      } else if (provider.userName.isNotEmpty && provider.userName.toLowerCase() != 'user') {
        _handleController.text = provider.userName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _handleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionState() async {
    final granted = await NotificationService().isNotificationListenerGranted();
    if (mounted) {
      setState(() => _isTrackingEnabled = granted);
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1 ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> _handleSetGoal() async {
    try {
      final provider = context.read<SanchayProvider>();
      final existingTarget = provider.primaryTarget;

      if (existingTarget != null) {
        final updated = existingTarget.copyWith(
          targetCap: _selectedGoal,
          targetDate: DateTime.now().add(const Duration(days: 90)),
        );
        await provider.updateVault(updated);
      } else {
        final newVault = SanchayTarget(
          id: 'vault_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Primary Reserve',
          targetCap: _selectedGoal,
          targetDate: DateTime.now().add(const Duration(days: 90)),
          isPrimary: true,
          category: 'General',
          accentColorHex: '#10B981',
          iconName: 'savings',
        );
        await provider.createVault(newVault);
      }
    } catch (e) {
      debugPrint('Onboarding: error saving initial goal: $e');
    }

    _nextStep();
  }

  // ---------------------------------------------------------------------------
  // STEP 2 ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> _handleEnableTracking() async {
    try {
      if (!kIsWeb) {
        await Permission.notification.request();
        await NotificationService().openNotificationListenerSettings();
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkPermissionState();
    } catch (e) {
      debugPrint('Onboarding: error requesting tracking permissions: $e');
    }

    _nextStep();
  }

  // ---------------------------------------------------------------------------
  // STEP 3 ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> _handleClaimHandleAndFinish() async {
    final rawHandle = _handleController.text.trim().toLowerCase();
    final validationError = ProfileService().validateHandle(rawHandle);

    if (validationError != null) {
      setState(() => _handleError = validationError);
      return;
    }

    setState(() {
      _isSavingHandle = true;
      _handleError = null;
    });

    try {
      // 1. Update handle in Firestore & local provider
      await ProfileService().updateHandle(newHandle: rawHandle, context: context);

      // 2. Mark onboarding completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);

      if (!mounted) return;
      Navigator.of(context).pop();

      CenterAlert.show(
        context,
        message: 'Welcome to Sanchay Cockpit',
        subtitle: 'Handle @$rawHandle claimed • Autonomous pacing active',
        icon: Icons.rocket_launch_rounded,
        iconColor: AppColors.emerald,
      );
    } catch (e) {
      setState(() {
        _isSavingHandle = false;
        _handleError = e.toString().replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
      });
    }
  }

  Future<void> _skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withOpacity(0.16),
            blurRadius: 36,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pull Handle Indicator
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Top Indicator Row: Step Pill + Skip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Step Pill Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldFixed.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'STEP ${_currentStep + 1} OF 3',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                      ),

                      // Segmented Step Dots
                      Row(
                        children: List.generate(3, (index) {
                          final isActive = index == _currentStep;
                          final isDone = index < _currentStep;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.obsidian
                                  : (isDone ? AppColors.emerald : AppColors.surfaceVariant),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),

                      // Skip Button
                      GestureDetector(
                        onTap: _skipOnboarding,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content Page View
                  SizedBox(
                    height: 380,
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) => setState(() => _currentStep = index),
                      children: [
                        _buildStep1GoalView(),
                        _buildStep2TrackingView(),
                        _buildStep3HandleView(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 1: SET YOUR FIRST VAULT TARGET
  // ===========================================================================
  Widget _buildStep1GoalView() {
    final provider = context.watch<SanchayProvider>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Visual: Target Flag Icon Capsule
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: AppColors.obsidian.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.flag_rounded, color: AppColors.emerald, size: 30),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Set Your First Vault Target',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.obsidian,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Sanchay calculates your daily runway based on this goal.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Live Selected Amount Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Text(
            provider.formatCurrency(_selectedGoal),
            style: AppTheme.monoNumeric(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.obsidian,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Quick Preset Chips
        Wrap(
          spacing: 8,
          children: _presetGoals.map((val) {
            final isSelected = _selectedGoal == val;
            return GestureDetector(
              onTap: () => setState(() => _selectedGoal = val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.obsidian : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? AppColors.obsidian : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: Text(
                  '₹${(val / 1000).toInt()}k',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.obsidian,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Numeric Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.emerald,
            inactiveTrackColor: AppColors.surfaceContainerHigh,
            thumbColor: AppColors.obsidian,
            overlayColor: AppColors.emerald.withOpacity(0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: _selectedGoal.clamp(10000.0, 500000.0),
            min: 10000.0,
            max: 500000.0,
            divisions: 49,
            onChanged: (val) => setState(() => _selectedGoal = val),
          ),
        ),
        const Spacer(),

        // Primary Action
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _handleSetGoal,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Set Goal',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 2: ENABLE ZERO-EFFORT TRACKING
  // ===========================================================================
  Widget _buildStep2TrackingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Clean Visual: Green Radar Animation Pill
        AnimatedBuilder(
          animation: _radarController,
          builder: (context, child) {
            return SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse Ring 1
                  Container(
                    width: 70 + (_radarController.value * 20),
                    height: 70 + (_radarController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.emerald.withOpacity((1.0 - _radarController.value) * 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Pulse Ring 2
                  Container(
                    width: 50 + (_radarController.value * 25),
                    height: 50 + (_radarController.value * 25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.emerald.withOpacity((1.0 - _radarController.value) * 0.15),
                    ),
                  ),
                  // Center Radar Badge
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.emerald,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.sensors_rounded, color: Colors.white, size: 26),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        Text(
          'Enable Zero-Effort Tracking',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.obsidian,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Grant notification permission once so your UPI payments log themselves silently.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Live Radar Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isTrackingEnabled ? AppColors.emeraldFixed : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _isTrackingEnabled
                  ? AppColors.emerald.withOpacity(0.3)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isTrackingEnabled ? AppColors.emerald : AppColors.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isTrackingEnabled ? 'Auto-Tracking Active' : 'Waiting for Permission',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _isTrackingEnabled ? AppColors.emeraldDark : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),

        // Primary Action: Enable Auto-Tracking
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _handleEnableTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded, size: 20, color: AppColors.emerald),
                const SizedBox(width: 8),
                Text(
                  _isTrackingEnabled ? 'Continue' : 'Enable Auto-Tracking',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 3: CLAIM YOUR UNIQUE HANDLE
  // ===========================================================================
  Widget _buildStep3HandleView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Clean Visual: Identity Card Pill
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: AppColors.obsidian.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.alternate_email_rounded, color: AppColors.obsidian, size: 28),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Claim Your Unique Handle',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.obsidian,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Friends can discover and message you using this handle.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Handle Input Field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _handleError != null ? AppColors.crimson : Colors.black.withOpacity(0.08),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _handleController,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.obsidian,
            ),
            decoration: InputDecoration(
              prefixText: '@',
              prefixStyle: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.emerald,
              ),
              border: InputBorder.none,
              hintText: 'yourname',
              hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: 15,
                color: AppColors.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            onChanged: (_) {
              if (_handleError != null) setState(() => _handleError = null);
            },
          ),
        ),

        if (_handleError != null) ...[
          const SizedBox(height: 8),
          Text(
            _handleError!,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.crimson,
            ),
          ),
        ],

        const Spacer(),

        // Action: Enter Cockpit
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSavingHandle ? null : _handleClaimHandleAndFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSavingHandle
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Enter Cockpit',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.emerald),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
