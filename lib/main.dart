import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lorenz_app/Home.dart';
import 'package:lorenz_app/OnBoardingPage.dart';
import 'package:lorenz_app/LoginPage.dart';
import 'package:lorenz_app/admin/modern_admin_dashboard.dart';
import 'package:lorenz_app/models/appointment.dart';
import 'package:lorenz_app/models/feedback_model.dart';
import 'package:lorenz_app/models/user_model.dart';
import 'package:lorenz_app/services/secure_auth_service.dart';
import 'package:lorenz_app/services/cache_service.dart';
import 'package:lorenz_app/services/monitoring_service.dart';
import 'package:lorenz_app/config/environment.dart';
import 'package:lorenz_app/widgets/error_boundary.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize environment variables
  await Environment.initialize();

  // Print configuration in debug mode
  if (kDebugMode) {
    Environment.printConfig();
  }

  // ✅ Validate environment configuration (warning only, don't crash)
  if (!Environment.validateConfig() && Environment.isProduction) {
    if (kDebugMode) {
      print(
          'Warning: Invalid environment configuration. Check your .env file.');
    }
  }

  // ✅ Firebase initialization (check if already initialized to prevent duplicate app error)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Firebase might already be initialized by native code or hot reload
    // Ignore duplicate app error, throw others
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }

  // ✅ Firebase App Check - DISABLED for now to avoid 403 throttling errors
  // To enable: Configure reCAPTCHA v3 in Firebase Console and add key to .env
  // if (!kDebugMode) {
  //   try {
  //     final recaptchaKey = Environment.recaptchaV3SiteKey;
  //
  //     await FirebaseAppCheck.instance.activate(
  //       androidProvider: AndroidProvider.playIntegrity,
  //       appleProvider: AppleProvider.deviceCheck,
  //       webProvider: recaptchaKey.isNotEmpty
  //           ? ReCaptchaV3Provider(recaptchaKey)
  //           : ReCaptchaV3Provider('6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI'),
  //     );
  //   } catch (e) {
  //     print('Warning: Firebase App Check activation failed: $e');
  //   }
  // }
  print('ℹ️ Firebase App Check disabled to prevent 403 errors');

  // ✅ Initialize MonitoringService for error tracking
  final monitoring = MonitoringService();

  // ✅ Capture Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      // Show error in debug mode
      FlutterError.presentError(details);
    }
    // Log to monitoring service
    monitoring.logError(
      'Flutter Framework Error',
      details.exception,
      stackTrace: details.stack,
      metadata: {
        'library': details.library ?? 'unknown',
        'context': details.context?.toString() ?? 'no context',
      },
    );
  };

  // ✅ Hive initialization
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(AppointmentAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(FeedbackModelAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(UserModelAdapter());
  }

  await Hive.openBox<Appointment>('appointments');
  await Hive.openBox<FeedbackModel>('feedbackBox');
  await Hive.openBox<UserModel>('users');
  await Hive.openBox('session');

  // ⚠️ REMOVED: Hardcoded user creation with plain text passwords
  // Users must now be created through Firebase Auth only
  // Admin users should be created via Firebase Console

  // Initialize CacheService (required for admin dashboard)
  try {
    await CacheService.instance.initialize();
  } catch (e) {
    // Log error but continue
    monitoring.logWarning('CacheService initialization failed',
        metadata: {'error': e.toString()});
  }

  // ✅ Run app with global error handler and error boundary
  runZonedGuarded(
    () {
      runApp(
        ErrorBoundary(
          onError: (error, stackTrace) {
            // Log errors caught by ErrorBoundary
            monitoring.logCritical(
              'UI Error (ErrorBoundary)',
              error,
              stackTrace: stackTrace,
              metadata: {
                'source': 'ErrorBoundary',
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          },
          child: const ProviderScope(child: MyApp()),
        ),
      );
    },
    (error, stack) {
      // Capture uncaught async errors
      monitoring.logCritical(
        'Uncaught Async Error',
        error,
        stackTrace: stack,
        metadata: {
          'source': 'runZonedGuarded',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF225FFF)),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
      },
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 800), () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check user role to redirect to appropriate page
        Widget targetPage = const HomePage(); // Default for users

        try {
          final authService = SecureAuthService();
          final userProfile = await authService.getUserProfile(user.uid);

          // Redirect admins to admin dashboard
          if (userProfile.role == UserRole.admin) {
            targetPage = const ModernAdminDashboard();
          }

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => targetPage,
              transitionsBuilder: (_, animation, __, child) => FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
          return;
        } catch (e) {
          // If error getting profile (permission denied, user doesn't exist, etc.),
          // sign out and redirect to login
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const LoginPage(),
              transitionsBuilder: (_, animation, __, child) => FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
          return;
        }
      } else {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => OnBoardingPage(),
            transitionsBuilder: (_, animation, __, child) => SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOut)),
              child: FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeIn),
                child: child,
              ),
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          // Responsive sizing for desktop vs mobile
          final isDesktop = screenWidth > 800;
          final isLargeDesktop = screenWidth > 1200;

          // Calculate appropriate image size based on screen
          double imageSize;
          double topOffset;

          if (isLargeDesktop) {
            // Large desktop: constrain image to reasonable size
            imageSize = screenHeight * 0.5; // 50% of screen height
            topOffset = screenHeight * 0.25;
          } else if (isDesktop) {
            // Regular desktop: moderate size
            imageSize = screenHeight * 0.6;
            topOffset = screenHeight * 0.2;
          } else {
            // Mobile/tablet: original behavior
            imageSize = screenWidth;
            topOffset = screenHeight * 0.25;
          }

          return Container(
            width: screenWidth,
            height: screenHeight,
            decoration: const BoxDecoration(
              color: Color(0xFF225FFF),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: topOffset,
                  child: Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: const AssetImage("assets/motoq1.png"),
                        // Use contain for desktop to prevent blur/zoom
                        // Use cover for mobile for full-width display
                        fit: isDesktop ? BoxFit.contain : BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
