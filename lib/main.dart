import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/sanchay_provider.dart';
import 'providers/vault_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_messages_list_screen.dart';
import 'screens/ledger_screen.dart';
import 'screens/main_navigation_shell.dart';
import 'screens/preferences_screen.dart';
import 'screens/targets_screen.dart';
import 'screens/app_guide_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/sanchay_logo.dart';

/// Safe asynchronous initialization routine with strict timeouts
/// Eliminates startup deadlocks and ensures runApp() is never blocked indefinitely.
Future<void> initializeAppSafe() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase with a strict 4-second timeout
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        debugPrint('Firebase init timed out, proceeding offline...');
        return Firebase.app();
      },
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // 2. Configure Firestore offline persistence with unlimited cache
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    AuthService.firestoreInstance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firestore settings error: $e');
  }

  // 3. Non-blocking initial public profile sync (strict 3-second timeout)
  try {
    unawaited(
      AuthService().syncPublicProfile().timeout(
        const Duration(seconds: 3),
        onTimeout: () => debugPrint('Initial public profile sync timed out, continuing...'),
      ),
    );
  } catch (e) {
    debugPrint('Initial public profile sync error: $e');
  }

  // 4. Non-blocking NotificationService & FcmService initialization (strict 3-second timeout)
  try {
    await NotificationService().initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () => debugPrint('NotificationService init timed out, continuing...'),
    );
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  try {
    await FcmService().initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () => debugPrint('FcmService init timed out, continuing...'),
    );
  } catch (e) {
    debugPrint('FcmService init error: $e');
  }
}

void main() async {
  await initializeAppSafe();

  // Transparent status bar for immersive frosted glass feel
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SanchayProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
      ],
      child: const SanchayApp(),
    ),
  );
}

final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

class SanchayApp extends StatelessWidget {
  const SanchayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: FcmService.navigatorKey,
      navigatorObservers: [routeObserver],
      title: 'Sanchat Wealth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ColdStartAuthGate(),
      routes: {
        '/dashboard': (context) => const MainNavigationShell(),
        '/app': (context) => const MainNavigationShell(),
        '/auth': (context) => const AuthScreen(),
        '/preferences': (context) => const PreferencesScreen(),
        '/chat': (context) => const ChatMessagesListScreen(),
        '/ledger': (context) => const LedgerScreen(),
        '/targets': (context) => const TargetsScreen(),
        '/guide': (context) => const AppGuideScreen(),
        '/app-guide': (context) => const AppGuideScreen(),
      },
    );
  }
}

/// Cold-start authentication gate that eliminates splash screen deadlocks
/// and resolves cached authentication instantly on cold start.
class ColdStartAuthGate extends StatefulWidget {
  const ColdStartAuthGate({super.key});

  @override
  State<ColdStartAuthGate> createState() => _ColdStartAuthGateState();
}

class _ColdStartAuthGateState extends State<ColdStartAuthGate> {
  User? _currentUser;
  bool _isResolved = false;
  StreamSubscription<User?>? _authSubscription;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();

    // 1. Instant check from local secure storage/preferences
    try {
      final cachedUser = FirebaseAuth.instance.currentUser;
      if (cachedUser != null) {
        _currentUser = cachedUser;
        _isResolved = true;
      }
    } catch (e) {
      debugPrint('ColdStartAuthGate cached user check: $e');
    }

    // 2. Real-time auth stream listener
    try {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (user) {
          if (mounted) {
            setState(() {
              _currentUser = user;
              _isResolved = true;
            });
            _fallbackTimer?.cancel();
          }
        },
        onError: (e) {
          debugPrint('ColdStartAuthGate auth state changes error: $e');
          if (mounted) {
            setState(() {
              _currentUser ??= FirebaseAuth.instance.currentUser;
              _isResolved = true;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('ColdStartAuthGate subscription error: $e');
      _isResolved = true;
    }

    // 3. Strict 2.5-second fallback timer: never leave the user frozen on splash
    if (!_isResolved) {
      _fallbackTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && !_isResolved) {
          debugPrint('ColdStartAuthGate fallback triggered, proceeding...');
          setState(() {
            _currentUser = FirebaseAuth.instance.currentUser;
            _isResolved = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isResolved) {
      return const _SanchaySplashLoading();
    }

    if (_currentUser != null) {
      return const MainNavigationShell();
    }

    return const AuthScreen();
  }
}

class _SanchaySplashLoading extends StatelessWidget {
  const _SanchaySplashLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SanchatLogo(size: 64),
            const SizedBox(height: 20),
            Text(
              'SANCHAT',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 1.5,
                color: AppColors.obsidian,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Resilient Wealth Engine',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.obsidian,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
