import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';
import '../services/fcm_service.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/ambient_background.dart';
import '../widgets/biometric_lock_overlay.dart';
import '../widgets/bottom_nav.dart';
import 'dashboard_screen.dart';
import 'ledger_screen.dart';
import 'settings_screen.dart';
import 'targets_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  int _sessionCount = 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    ChatService().startDeliveryWatcher();
    ChatService().syncCurrentUserProfile();
    FriendService().startFriendRequestListener();
    _initSessionCount();

    // Check for pending cold-start notification navigation and ensure device token is synced
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService().registerCurrentDeviceToken();
      FcmService().checkAndNavigatePendingInitialMessage(context);
    });
  }

  Future<void> _initSessionCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('dashboard_session_count') ?? 1;
    if (mounted) {
      setState(() => _sessionCount = count);
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  void _openAddCommitModal() {
    AddTransactionModal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onOpenSettings: () => _onTabSelected(3)),
      const TargetsScreen(),
      const LedgerScreen(),
      SettingsScreen(onClose: () => _onTabSelected(0)),
    ];

    return BiometricLockOverlay(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AmbientBackground(
          child: Stack(
            children: [
              // Active Tab Page
              IndexedStack(
                index: _currentIndex,
                children: screens,
              ),

              // Suspended Frosted Glass Bottom Navigation Bar
              BottomNav(
                currentIndex: _currentIndex,
                onTabSelected: _onTabSelected,
                onAddPressed: _openAddCommitModal,
                showAddHighlight: _sessionCount <= 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
