import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lorenz_app/services/secure_auth_service.dart';

// Secure Auth Service Provider
final secureAuthServiceProvider = Provider<SecureAuthService>((ref) {
  return SecureAuthService();
});

// Auth State Provider
final authStateProvider = StreamProvider<User?>((ref) {
  // Use ref.read() to avoid creating circular dependencies
  final authService = ref.read(secureAuthServiceProvider);
  return authService.authStateChanges();
});

// User Profile Provider
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  // Use ref.read() to avoid creating circular dependencies
  final authService = ref.read(secureAuthServiceProvider);

  return authService.authStateChanges().asyncMap((user) async {
    if (user == null) return null;

    try {
      return await authService.getUserProfile(user.uid);
    } catch (e) {
      return null;
    }
  });
});

// Current User Profile Provider (for immediate access)
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // Use ref.read() to avoid creating circular dependencies
  final authService = ref.read(secureAuthServiceProvider);
  final user = authService.currentUser;

  if (user == null) return null;

  try {
    return await authService.getUserProfile(user.uid);
  } catch (e) {
    return null;
  }
});

// Session Validity Provider
final sessionValidityProvider = FutureProvider<bool>((ref) async {
  // Use ref.read() to avoid creating circular dependencies
  final authService = ref.read(secureAuthServiceProvider);
  return await authService.isSessionValid();
});

// Permission Check Provider
final permissionProvider = Provider.family<bool, String>((ref, permission) {
  final userProfile = ref.watch(userProfileProvider);

  return userProfile.when(
    data: (profile) => profile?.hasPermission(permission) ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Admin Access Provider
final adminAccessProvider = Provider<bool>((ref) {
  final userProfile = ref.watch(userProfileProvider);

  return userProfile.when(
    data: (profile) => profile?.canAccessAdmin() ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Auth State Notifier for managing authentication actions
class AuthNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final SecureAuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _initializeAuth();
  }

  void _initializeAuth() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final profile = await _authService.getUserProfile(user.uid);
        state = AsyncValue.data(profile);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
    String? ipAddress,
    String? userAgent,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userProfile = await _authService.signInWithEmail(
        email: email,
        password: password,
        ipAddress: ipAddress,
        userAgent: userAgent,
      );
      state = AsyncValue.data(userProfile);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    UserRole role = UserRole.user,
    String? ipAddress,
    String? userAgent,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userProfile = await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        ipAddress: ipAddress,
        userAgent: userAgent,
      );
      state = AsyncValue.data(userProfile);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> signInWithGoogle({
    String? ipAddress,
    String? userAgent,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userProfile = await _authService.signInWithGoogle(
        ipAddress: ipAddress,
        userAgent: userAgent,
      );
      state = AsyncValue.data(userProfile);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> signOut({
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _authService.signOut(
        ipAddress: ipAddress,
        userAgent: userAgent,
      );
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refreshProfile() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final profile = await _authService.getUserProfile(user.uid);
        state = AsyncValue.data(profile);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

// Auth Notifier Provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserProfile?>>((ref) {
  final authService = ref.watch(secureAuthServiceProvider);
  return AuthNotifier(authService);
});

// Convenience provider for getting current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  // Use ref.read() to avoid creating circular dependencies
  final authService = ref.read(secureAuthServiceProvider);
  return authService.currentUser?.uid;
});

// Convenience provider for checking if user is logged in
final isLoggedInProvider = Provider<bool>((ref) {
  // Use ref.read() to avoid creating circular dependencies
  final authService = ref.read(secureAuthServiceProvider);
  return authService.currentUser != null;
});