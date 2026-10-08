import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/sanchay_provider.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_bridge.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/center_hud_alert.dart';
import '../widgets/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/profile_image_picker_modal.dart';
import '../widgets/top_glass_bar.dart';
import '../services/statement_service.dart';
import '../services/backup_service.dart';
import '../widgets/brand_logo.dart';
import 'gamification_hub_screen.dart';

typedef SettingsScreen = PreferencesScreen;

class PreferencesScreen extends StatefulWidget {
  final VoidCallback? onClose;

  const PreferencesScreen({super.key, this.onClose});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _syncSpinController;
  bool _isNotificationPermissionGranted = false;

  late TextEditingController _handleController;
  bool _isSavingHandle = false;
  bool _isHandleDirty = false;
  String? _handleError;
  bool _handleInitialized = false;
  Timer? _handleDebounceTimer;
  bool _isCheckingHandle = false;
  bool _isHandleAvailable = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _handleController = TextEditingController();
    _checkNotificationPermission();
    _loadBiometricPreference();
  }

  Future<void> _loadBiometricPreference() async {
    final enabled = await BiometricService().isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBiometricEnabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSpinController.dispose();
    _handleDebounceTimer?.cancel();
    _handleController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_handleInitialized) {
      final handle = context.read<SanchayProvider>().userHandle;
      if (handle.isNotEmpty) {
        _handleController.text = handle;
        _handleInitialized = true;
      }
    }
  }

  void _onHandleChanged(String val) {
    setState(() {
      _isHandleDirty = true;
      _handleError = null;
      _isHandleAvailable = false;
    });

    _handleDebounceTimer?.cancel();
    final input = val.trim();
    if (input.isEmpty) {
      setState(() => _isCheckingHandle = false);
      return;
    }

    final validationError = ProfileService().validateHandle(input);
    if (validationError != null) {
      setState(() {
        _handleError = validationError;
        _isCheckingHandle = false;
      });
      return;
    }

    setState(() => _isCheckingHandle = true);

    _handleDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      var clean = input.toLowerCase();
      if (clean.startsWith('@')) clean = clean.substring(1);
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      try {
        final existing = await AuthService.firestoreInstance
            .collection('public_profiles')
            .where('handle', isEqualTo: clean)
            .limit(1)
            .get();

        if (!mounted) return;
        if (existing.docs.isNotEmpty && existing.docs.first.id != currentUid) {
          setState(() {
            _isCheckingHandle = false;
            _handleError = 'Username already taken';
            _isHandleAvailable = false;
          });
        } else {
          setState(() {
            _isCheckingHandle = false;
            _handleError = null;
            _isHandleAvailable = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isCheckingHandle = false);
        }
      }
    });
  }

  Future<void> _handleSaveUsername(SanchayProvider provider) async {
    final input = _handleController.text.trim();
    final validationError = ProfileService().validateHandle(input);
    if (validationError != null) {
      setState(() => _handleError = validationError);
      return;
    }

    setState(() {
      _isSavingHandle = true;
      _handleError = null;
    });

    try {
      var clean = input.toLowerCase();
      if (clean.startsWith('@')) clean = clean.substring(1);
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final existing = await AuthService.firestoreInstance
          .collection('public_profiles')
          .where('handle', isEqualTo: clean)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty && existing.docs.first.id != currentUid) {
        if (mounted) {
          setState(() {
            _isSavingHandle = false;
            _handleError = 'Username already taken';
            _isHandleAvailable = false;
          });
        }
        return;
      }

      if (!mounted) return;
      await ProfileService().updateUsername(
        context: context,
        newHandle: clean,
      );

      if (mounted) {
        setState(() {
          _isSavingHandle = false;
          _isHandleDirty = false;
          _isHandleAvailable = true;
        });
        showCenterAlert(
          context,
          message: 'Username updated to @$clean',
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF10B981),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingHandle = false;
          _handleError = e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '').replaceAll('ArgumentError: ', '');
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  void _checkNotificationPermission() async {
    final granted = await NotificationBridge().isPermissionGranted();
    if (mounted) {
      setState(() => _isNotificationPermissionGranted = granted);
      try {
        context.read<SanchayProvider>().checkNotificationPermission();
      } catch (_) {}
    }
  }


  void _showExportDialog(BuildContext context, SanchayProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.crimson.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.file_download_outlined, color: AppColors.crimson, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Data & Statements',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.obsidian,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select desired file format below',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Option 1: Download Excel / CSV Statement
            InkWell(
              onTap: () async {
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Generating Sanchay CSV Statement...'),
                      ],
                    ),
                    duration: Duration(seconds: 1),
                  ),
                );
                final res = await StatementService().exportAndShareStatement(provider: provider);
                if (!context.mounted) return;
                if (!res.success && res.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to export statement: ${res.errorMessage}'),
                      backgroundColor: AppColors.crimson,
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.table_chart_rounded, color: AppColors.emeraldDark, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Download Excel / CSV Statement',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.obsidian,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Detailed readable bank ledger with signed credits/debits formatted for Microsoft Excel & Google Sheets.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Export Full JSON Backup
            InkWell(
              onTap: () async {
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Preparing complete JSON backup...'),
                      ],
                    ),
                    duration: Duration(seconds: 1),
                  ),
                );
                final res = await BackupService().exportBackup(provider: provider);
                if (!context.mounted) return;
                if (!res.success && res.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to export backup: ${res.errorMessage}'),
                      backgroundColor: AppColors.crimson,
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.cloud_upload_outlined, color: AppColors.obsidian, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export Full JSON Backup',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.obsidian,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Machine-readable complete system backup for migrating or restoring ledger, multi-vault goals, and preferences.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context, SanchayProvider provider) async {
    try {
      final res = await BackupService().restoreBackup(provider: provider);

      if (!context.mounted) return;
      if (res.wasCancelled) return;

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✓ Successfully restored ${res.restoredTransactions} transactions and ${res.restoredVaults} vaults',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.emeraldDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on BackupValidationException catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, e.message);
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, 'Invalid Sanchay backup file format');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.error_outline_rounded, color: AppColors.crimson, size: 24),
            SizedBox(width: 8),
            Text('Backup Error', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPurgeConfirmation(BuildContext context, SanchayProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.obsidian.withOpacity(0.12),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                Icon(Icons.warning, color: AppColors.crimson, size: 24),
                SizedBox(width: 8),
                Text(
                  'Purge Transaction Ledger?',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'This will irreversibly delete all local transaction history. Cloud reserves, vault targets, and settings will remain intact.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      provider.purgeTransactions();
                      Navigator.of(ctx).pop();
                      showCenterAlert(
                        context,
                        message: 'Ledger Purged',
                        subtitle: 'All transaction history cleared',
                        icon: Icons.delete_sweep_rounded,
                        iconColor: AppColors.crimson,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.crimson,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Purge All', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SanchayProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        bottom: false, // Navigation dock handles bottom clearance
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Responsive App Header
            SliverToBoxAdapter(
              child: SanchayUnifiedHeader(
                showBackButton: widget.onClose != null,
                onBack: widget.onClose,
              ),
            ),

            // Screen Body with Strict Spacing & Bottom Dock Clearance
            SliverPadding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 140),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  _buildBreadcrumbBar(context),
                  const SizedBox(height: 20),
                  _buildAccountVaultSection(context, provider),
                  const SizedBox(height: 20),
                  _buildAutomationSection(context, provider),
                  const SizedBox(height: 20),
                  _buildDataOwnershipSection(context, provider),
                  const SizedBox(height: 20),
                  _buildPrivacyAndComplianceSection(context),
                  const SizedBox(height: 20),
                  _buildSignOutSection(context),
                  const SizedBox(height: 24),
                  _buildFooter(),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SYSTEM CONFIGURATION',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Preferences',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
      ],
    );
  }

  Widget _buildAccountVaultSection(BuildContext context, SanchayProvider provider) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        final displayName = user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email?.split('@').first ??
                (provider.userName.isNotEmpty ? provider.userName : 'User'));
        final email = user?.email ??
            (provider.userEmail.isNotEmpty ? provider.userEmail : 'No email associated');

        final photoURL = (user?.photoURL?.isNotEmpty == true)
            ? user!.photoURL!
            : provider.userAvatarUrl;

        return GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      await ProfileImagePickerModal.show(context);
                      if (mounted) setState(() {});
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.obsidian.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: buildUserAvatar(
                            photoURL,
                            radius: 28,
                            initials: displayName.isNotEmpty ? displayName.substring(0, 1) : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.obsidian,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.edit, size: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldFixed.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.verified, size: 12, color: AppColors.onEmeraldFixedVariant),
                                  SizedBox(width: 3),
                                  Text(
                                    'Pro Vault',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onEmeraldFixedVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.monoNumeric(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign Out / Switch Vault Account',
                    onPressed: () async {
                      try {
                        await GoogleSignIn().signOut();
                      } catch (e) {
                        debugPrint('GoogleSignIn signOut error: $e');
                      }
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
                    },
                    icon: const Icon(Icons.logout, size: 18, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Editable Username / Handle field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _handleError != null
                        ? AppColors.crimson
                        : Colors.black.withOpacity(0.06),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'USERNAME / HANDLE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            if (_isCheckingHandle) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'checking...',
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF64748B)),
                              ),
                            ] else if (_isHandleAvailable && _handleError == null && _handleController.text.trim().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                'Available',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_isSavingHandle)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_isHandleDirty)
                          GestureDetector(
                            onTap: () => _handleSaveUsername(provider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.obsidian,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'SAVE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '@',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.crimson,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _handleController,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.obsidian,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'username',
                              hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: InputBorder.none,
                            ),
                            onChanged: _onHandleChanged,
                            onSubmitted: (_) => _handleSaveUsername(provider),
                          ),
                        ),
                      ],
                    ),
                    if (_handleError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _handleError!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.crimson,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

          // Cloud Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.cloud_done, size: 18, color: AppColors.emerald),
                    SizedBox(width: 8),
                    Text(
                      'Cloud Connected (Firestore)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.emerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Live',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Biometric Lock
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fingerprint, size: 20, color: AppColors.onSurface),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Biometric App Lock',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'Require Fingerprint or Face ID',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _isBiometricEnabled,
                activeColor: Colors.white,
                activeTrackColor: AppColors.obsidian,
                onChanged: (value) async {
                  final messenger = ScaffoldMessenger.of(context);
                  await BiometricService().setBiometricEnabled(value, userId: provider.currentUserId);
                  await provider.setBiometricLock(value);
                  if (!mounted) return;
                  setState(() {
                    _isBiometricEnabled = value;
                  });
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Biometric Lock ${value ? 'Enabled' : 'Disabled'}'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildAutomationSection(BuildContext context, SanchayProvider provider) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt, size: 20, color: AppColors.crimson),
              SizedBox(width: 8),
              Text(
                'Automation & Detection',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Switch: Background UPI Interceptor
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Background UPI Interceptor',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Detect and classify incoming/outgoing UPI transfers in real-time background service',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: provider.upiInterceptor,
                activeColor: Colors.white,
                activeTrackColor: AppColors.obsidian,
                onChanged: (_) => provider.toggleUpiInterceptor(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notification Access (Clean, modern styling without green tint artifacts)
          InkWell(
            onTap: () async {
              await NotificationBridge().openSettings();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isNotificationPermissionGranted
                              ? AppColors.emerald.withOpacity(0.12)
                              : AppColors.crimson.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                          color: _isNotificationPermissionGranted
                              ? AppColors.emerald
                              : AppColors.crimson,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'System Notification Access',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isNotificationPermissionGranted
                                ? 'Permission granted for background reader'
                                : 'Tap to enable notification listener',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isNotificationPermissionGranted
                          ? AppColors.emerald.withOpacity(0.12)
                          : AppColors.crimson.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _isNotificationPermissionGranted
                                ? AppColors.emerald
                                : AppColors.crimson,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isNotificationPermissionGranted
                              ? 'Active'
                              : 'Grant Access',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _isNotificationPermissionGranted
                                ? AppColors.emerald
                                : AppColors.crimson,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!_isNotificationPermissionGranted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => NotificationBridge().openSettings(),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text(
                  'Grant System Notification Access',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataOwnershipSection(BuildContext context, SanchayProvider provider) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.storage, size: 20, color: AppColors.crimson),
              SizedBox(width: 8),
              Text(
                'Data Ownership & Storage',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _showExportDialog(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainer,
                      foregroundColor: AppColors.onSurface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text(
                      'Export JSON / CSV',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _showImportDialog(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainer,
                      foregroundColor: AppColors.onSurface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text(
                      'Import Backup',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: provider.isSyncing
                  ? null
                  : () async {
                      _syncSpinController.repeat();
                      await provider.forceCloudSync();
                      _syncSpinController.stop();
                      _syncSpinController.reset();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.obsidian,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        RotationTransition(
                          turns: _syncSpinController,
                          child: const Icon(Icons.sync, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Force Cloud Sync Now',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      provider.isSyncing
                          ? 'Syncing...'
                          : 'Synced: ${DateFormat('hh:mm a').format(provider.lastSyncedTime)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Danger Zone Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.crimsonFixed.withOpacity(0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.crimson),
                    SizedBox(width: 6),
                    Text(
                      'Danger Zone',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.crimson,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Irreversibly resets local transaction history. Cloud reserves remain intact.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPurgeConfirmation(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.crimson,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text(
                      'Purge Transaction Ledger',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteAccountConfirmation(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.crimson,
                      side: const BorderSide(color: AppColors.crimson, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.person_remove_rounded, size: 18),
                    label: const Text(
                      'Delete Account Permanently',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyAndComplianceSection(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield_outlined, color: AppColors.emerald, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy & Google Play Safety',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.obsidian,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Data governance, permissions & policy disclosures',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildComplianceTile(
            icon: Icons.policy_outlined,
            title: 'Sanchat Privacy Policy',
            subtitle: 'Read our end-to-end data safety & zero advertising pledge',
            onTap: () => _showPrivacyPolicyModal(context),
          ),
          const Divider(height: 20, thickness: 0.8, color: Color(0xFFE2E8F0)),
          _buildComplianceTile(
            icon: Icons.lock_person_outlined,
            title: 'Permissions & Transparency',
            subtitle: 'Audit SMS, notification & biometric permissions used',
            onTap: () => _showPermissionsDisclosureModal(context),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.obsidianSlate),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.slateWhisper),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutSection(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => GamificationHubScreen.show(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.obsidian,
              side: BorderSide(color: AppColors.emerald.withOpacity(0.5), width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
            ),
            icon: const Text('🐣', style: TextStyle(fontSize: 18)),
            label: const Text(
              'Discipline Hub, Saving Pet & Universe',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.obsidian,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _showSignOutConfirmation(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.obsidianSlate,
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text(
              'Sign Out of Sanchat',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton.icon(
            onPressed: () => _showDeleteAccountConfirmation(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.crimson,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18, color: AppColors.crimson),
            label: const Text(
              'Delete Account & Data Permanently',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.crimson,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: const Text(
          'You can sign back in at any time. Your cloud vaults and settings remain securely synced.',
          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.crimson, size: 24),
            SizedBox(width: 8),
            Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.crimson)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'This action is PERMANENT and IRREVERSIBLE under Google Play data deletion policies.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.obsidian),
            ),
            SizedBox(height: 10),
            Text(
              'What will be permanently deleted:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
            ),
            SizedBox(height: 6),
            Text('• All savings vaults and financial targets', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
            Text('• Complete transaction ledger and history', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
            Text('• Public profile, handle, and friend connections', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
            Text('• Your Firebase Authentication user account', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
            SizedBox(height: 12),
            Text(
              'Are you sure you wish to permanently delete your account?',
              style: TextStyle(fontSize: 12, color: AppColors.crimson, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Account'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _performAccountDeletion(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crimson,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.crimson),
                SizedBox(height: 16),
                Text('Deleting account & data...', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await AuthService().deleteUserAccount();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Account Deletion Notice', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.obsidian,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showPrivacyPolicyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: const [
                  SanchatBrandLogo(size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Sanchat Privacy Policy',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.obsidian,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Package: com.aistudio.sanchay.savtrkr • Last Updated: October 2026',
                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
              const Divider(height: 24),
              _buildPolicySection(
                title: '1. Information We Collect & Process',
                body: 'Sanchat processes user profile information (email, display name, handle) for authentication and social savings connections. Financial records (vault goals, allocations, transaction logs) are stored under your private user ID.',
              ),
              _buildPolicySection(
                title: '2. On-Device Financial SMS & UPI Sync',
                body: 'When enabled by the user, Sanchat parses incoming bank transaction SMS and UPI notifications strictly ON-DEVICE using pattern matching to extract transaction amounts and bank tags. Sanchat NEVER reads personal messages, NEVER monitors OTPs, and NEVER transmits raw SMS message bodies to any external server.',
              ),
              _buildPolicySection(
                title: '3. Data Security & Storage',
                body: 'All data is transmitted via TLS 1.3 encryption. Cloud data is hosted on Google Cloud Firebase Firestore with strict per-user authorization rules. Users cannot view or modify another user\'s private financial targets.',
              ),
              _buildPolicySection(
                title: '4. Zero Sale of Personal Data',
                body: 'Sanchat does NOT sell, rent, or monetize your personal or financial information. We do not use third-party advertising SDKs or tracking pixels.',
              ),
              _buildPolicySection(
                title: '5. Account & Data Deletion Rights',
                body: 'In compliance with Google Play policy, users can permanently delete their account and all associated cloud data at any time under Settings > Danger Zone > Delete Account Permanently.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.obsidian,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionsDisclosureModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
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
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                Icon(Icons.lock_person_outlined, color: AppColors.emerald, size: 24),
                SizedBox(width: 10),
                Text(
                  'Permissions Transparency',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.obsidian,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildPermissionItem(
              name: 'READ_SMS (Optional)',
              desc: 'Enables automatic offline sync of bank debits and credits into your ledger. Only financial messages are parsed on-device.',
            ),
            _buildPermissionItem(
              name: 'Notification Listener (Optional)',
              desc: 'Enables instant capture of UPI payment notifications (e.g., GPay, PhonePe, Paytm) into your daily runway.',
            ),
            _buildPermissionItem(
              name: 'Biometric / Fingerprint (Optional)',
              desc: 'Enables hardware-level app lock for your personal vault privacy.',
            ),
            _buildPermissionItem(
              name: 'Exact Alarm (SCHEDULE_EXACT_ALARM)',
              desc: 'Delivers user-configured daily spending recap reminders at the scheduled time.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Understood'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.obsidian),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({required String name, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.obsidian),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const SanchatBrandLogo(size: 26),
        const SizedBox(height: 8),
        Text(
          'Sanchat — Smart Personal Finance',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Production Release • Version 1.0.0 (API 36 Ready)',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Private Financial Vault • Zero-Knowledge Architecture',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: AppColors.onSurfaceVariant.withOpacity(0.45),
          ),
        ),
      ],
    );
  }
}
