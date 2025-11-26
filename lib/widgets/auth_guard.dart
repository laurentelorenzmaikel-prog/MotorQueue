import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorenz_app/services/secure_auth_service.dart';
import 'package:lorenz_app/providers/auth_providers.dart';

class AuthGuard extends ConsumerStatefulWidget {
  final Widget child;
  final UserRole? requiredRole;
  final List<String>? requiredPermissions;
  final Widget? unauthorizedWidget;

  const AuthGuard({
    Key? key,
    required this.child,
    this.requiredRole,
    this.requiredPermissions,
    this.unauthorizedWidget,
  }) : super(key: key);

  @override
  ConsumerState<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends ConsumerState<AuthGuard> {
  // Cache all auth checks to prevent reactive rebuilds
  bool _isLoading = true;
  bool _isAuthorized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // DON'T call ref.read() in initState - causes _dependents.isEmpty error
    // Schedule for after first frame to ensure proper provider initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthorization();
    });
  }

  Future<void> _checkAuthorization() async {
    try {
      final authService = ref.read(secureAuthServiceProvider);
      final user = await ref.read(authStateProvider.future);

      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isAuthorized = false;
            _errorMessage = 'Please log in to access this page';
          });
        }
        return;
      }

      final profile = await ref.read(userProfileProvider.future);

      if (profile == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isAuthorized = false;
            _errorMessage = 'User profile not found';
          });
        }
        return;
      }

      if (!profile.isActive) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isAuthorized = false;
            _errorMessage = 'Account is deactivated';
          });
        }
        return;
      }

      // Check role requirement
      if (widget.requiredRole != null && profile.role != widget.requiredRole) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isAuthorized = false;
            _errorMessage = 'Insufficient permissions. ${widget.requiredRole.toString().split('.').last.toUpperCase()} role required.';
          });
        }
        return;
      }

      // Check permission requirements
      if (widget.requiredPermissions != null) {
        for (final permission in widget.requiredPermissions!) {
          if (!profile.hasPermission(permission)) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isAuthorized = false;
                _errorMessage = 'Insufficient permissions. Missing: $permission';
              });
            }
            return;
          }
        }
      }

      // Check session validity
      final isSessionValid = await authService.isSessionValid();
      if (!isSessionValid) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isAuthorized = false;
            _errorMessage = 'SESSION_EXPIRED';
          });
        }
        return;
      }

      // All checks passed
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthorized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthorized = false;
          _errorMessage = 'Authentication error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isAuthorized) {
      if (_errorMessage == 'SESSION_EXPIRED') {
        return _buildSessionExpiredPage(context);
      }
      return _buildUnauthorizedPage(context, _errorMessage ?? 'Access denied');
    }

    return widget.child;
  }

  Widget _buildUnauthorizedPage(BuildContext context, String message) {
    return widget.unauthorizedWidget ?? UnauthorizedPage(message: message);
  }

  Widget _buildSessionExpiredPage(BuildContext context) {
    return SessionExpiredPage();
  }
}

class AdminGuard extends AuthGuard {
  const AdminGuard({
    Key? key,
    required Widget child,
    Widget? unauthorizedWidget,
  }) : super(
          key: key,
          child: child,
          requiredRole: UserRole.admin,
          unauthorizedWidget: unauthorizedWidget,
        );
}

class PermissionGuard extends AuthGuard {
  const PermissionGuard({
    Key? key,
    required Widget child,
    required List<String> permissions,
    Widget? unauthorizedWidget,
  }) : super(
          key: key,
          child: child,
          requiredPermissions: permissions,
          unauthorizedWidget: unauthorizedWidget,
        );
}

class UnauthorizedPage extends StatelessWidget {
  final String message;

  const UnauthorizedPage({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security,
                    size: 64,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      ),
                      icon: const Icon(Icons.home),
                      label: const Text('Go Home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      ),
                      icon: const Icon(Icons.login),
                      label: const Text('Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SessionExpiredPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.access_time,
                    size: 64,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Session Expired',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your session has expired for security reasons. Please log in again to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.orange.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(secureAuthServiceProvider).signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Login Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}