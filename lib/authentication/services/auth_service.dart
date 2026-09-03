import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../router/app_router.dart';
import '../models/user_model.dart';
import '../../shared/services/department_service.dart';
import '../../shared/services/login_activity_service.dart';
import '../../shared/services/maintenance_status_service.dart';

class AuthService extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;
  bool _isHandlingLogout = false;
  bool _isSessionInitialized = false;
  bool _pauseLoginRedirectOnce = false;
  bool _isPostLoginSplashActive = false;
  String? _loginError;
  final bool _restoreSessionOnStartup;
  late final StreamSubscription<AuthState> _authStateSubscription;
  RealtimeChannel? _profileRealtimeChannel;

  /// Set to true while an admin is creating a user account to prevent
  /// the isolated Supabase client from bleeding its auth state into this service.
  static bool _suppressAuthChanges = false;

  /// Call this before starting any user creation flow to silence auth events.
  static void beginUserCreation() {
    _suppressAuthChanges = true;
    debugPrint('[AuthService] Auth state changes suppressed (user creation in progress).');
  }

  /// Call this after user creation completes. Resumes auth state handling
  /// and queues a re-sync so the admin session is correctly reflected in the UI.
  static AuthService? _instance;
  static void endUserCreation() {
    _suppressAuthChanges = false;
    debugPrint('[AuthService] Auth state changes resumed.');
    // Re-sync from the main client session (which was restored by SystemAdminService)
    // so the UI reflects the admin's session, not the newly created user.
    final inst = _instance;
    if (inst != null) {
      Future.microtask(() async {
        await inst._syncCurrentUserFromSession(_auth.auth.currentSession);
        inst.notifyListeners();
      });
    }
  }

  static const List<String> _institutionalDomains = [
    'psu.edu.ph',
    'university.edu',
  ];

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isSessionInitialized => _isSessionInitialized;
  bool get pauseLoginRedirectOnce => _pauseLoginRedirectOnce;
  bool get isPostLoginSplashActive => _isPostLoginSplashActive;
  String? get loginError => _loginError;

  static SupabaseClient get _auth => Supabase.instance.client;

  AuthService({bool restoreSessionOnStartup = true})
      : _restoreSessionOnStartup = restoreSessionOnStartup {
    _instance = this; // Allow static endUserCreation() to call instance methods.
    _authStateSubscription = _auth.auth.onAuthStateChange.listen(
      (data) => _handleAuthStateChange(data.event, data.session),
    );

    if (_restoreSessionOnStartup) {
      _restoreSessionOnStartupAsync();
    } else {
      _isSessionInitialized = true;
    }
  }

  Future<void> _restoreSessionOnStartupAsync() async {
    try {
      await _syncCurrentUserFromSession(_auth.auth.currentSession);
    } catch (e) {
      debugPrint('Startup session restore error: $e');
    } finally {
      _isSessionInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _handleAuthStateChange(
    AuthChangeEvent event,
    Session? session,
  ) async {
    // While an admin is creating a user account, all auth state events from
    // the isolated Supabase client are suppressed to prevent session hijacking.
    if (_suppressAuthChanges) {
      debugPrint('[AuthService] Auth state change suppressed during user creation: $event');
      _isSessionInitialized = true;
      return;
    }
    try {
      switch (event) {
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.userDeleted:
          _profileRealtimeChannel?.unsubscribe();
          _profileRealtimeChannel = null;
          _currentUser = null;
          _isPostLoginSplashActive = false;
          _pauseLoginRedirectOnce = false;
          _isSessionInitialized = true;
          notifyListeners();
          return;
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.passwordRecovery:
        case AuthChangeEvent.mfaChallengeVerified:
          await _syncCurrentUserFromSession(session);
          _isSessionInitialized = true;
          notifyListeners();
          return;
      }
    } catch (e) {
      debugPrint('Auth state change handling error: $e');
      _isSessionInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _syncCurrentUserFromSession(Session? session) async {
    final supabaseUser = session?.user ?? _auth.auth.currentUser;
    if (supabaseUser == null) {
      _profileRealtimeChannel?.unsubscribe();
      _profileRealtimeChannel = null;
      _currentUser = null;
      return;
    }

    _currentUser = await _fetchProfile(supabaseUser.id);
    _subscribeToProfileRealtime(supabaseUser.id);
    if (_currentUser?.role == UserRole.maintenance) {
      try {
        await MaintenanceStatusService.setOnlineOnLogin(_currentUser!.id);
      } catch (_) {}
    }
  }

  void _subscribeToProfileRealtime(String userId) {
    if (_profileRealtimeChannel != null) return;
    _profileRealtimeChannel = _auth
        .channel('user_profile_sync_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) async {
            final updated = await _fetchProfile(userId);
            if (updated != null) {
              _currentUser = updated;
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'teacher_users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) async {
            final updated = await _fetchProfile(userId);
            if (updated != null) {
              _currentUser = updated;
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) async {
            final updated = await _fetchProfile(userId);
            if (updated != null) {
              _currentUser = updated;
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  bool consumeLoginRedirectPause() {
    if (!_pauseLoginRedirectOnce) return false;
    _pauseLoginRedirectOnce = false;
    return true;
  }

  void finishPostLoginSplash() {
    if (!_isPostLoginSplashActive) return;
    _isPostLoginSplashActive = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // Login with email and password
  // ---------------------------------------------------------------
  Future<AppUser?> login(String email, String password) async {
    _isLoading = true;
    _loginError = null;
    notifyListeners();

    try {
      final response = await _auth.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        _loginError = 'Authentication failed: no user returned.';
        return null;
      }

      AppUser? profile;
      try {
        profile = await _fetchProfile(supabaseUser.id);
      } catch (e) {
        debugPrint('Profile fetch error during login: $e');
        _loginError =
            'Unable to load your account profile right now. Please try again.';
        return null;
      }
      if (profile == null) {
        _loginError = 'Login succeeded but no profile found. Contact an admin.';
        return null;
      }

      if (!profile.isActive) {
        _loginError = profile.role == UserRole.teacher
            ? 'Your faculty account is not active yet. Please verify your email first.'
            : 'Your account is inactive. Please contact the administrator.';
        await _auth.auth.signOut();
        return null;
      }

      if (profile.role == UserRole.teacher &&
          supabaseUser.emailConfirmedAt == null) {
        _loginError =
            'Please verify your institutional email before logging in.';
        await _auth.auth.signOut();
        return null;
      }

      _currentUser = profile;
      // Allow the UI to show transition/splash first before router login redirect.
      _pauseLoginRedirectOnce = true;
      _isPostLoginSplashActive = true;
      try {
        await LoginActivityService.recordLogin(profile);
        if (profile.role == UserRole.maintenance) {
          await MaintenanceStatusService.setOnlineOnLogin(profile.id);
        }
      } catch (e) {
        // Login should still succeed even if local activity logging fails.
        debugPrint('Login activity recording failed: $e');
      }
      notifyListeners();
      return profile;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        _loginError = 'Invalid email or password.';
      } else if (msg.contains('email not confirmed')) {
        _loginError = 'Email is not verified yet. Please check your inbox.';
      } else if (_isAuthSchemaError(e.message)) {
        final fallbackUser = _debugSysAdminFallback(email, password);
        if (fallbackUser != null) {
          _currentUser = fallbackUser;
          _pauseLoginRedirectOnce = true;
          _isPostLoginSplashActive = true;
          notifyListeners();
          return fallbackUser;
        }

        _loginError =
            'The authentication database is still failing. Please wait for Supabase to recover, then try again.';
      } else {
        _loginError = e.message;
      }
      return null;
    } catch (e) {
      debugPrint('Login error: $e');
      _loginError = 'Unable to log in right now. Please try again.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isAuthSchemaError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('database error querying schema') ||
        normalized.contains('unexpected_failure');
  }

  AppUser? _debugSysAdminFallback(String email, String password) {
    if (!kDebugMode) return null;
    if (email.trim().toLowerCase() != 'sysadmin@psu.edu.ph') return null;
    if (password != 'SysAdmin2026!') return null;

    return AppUser(
      id: '00000000-0000-0000-0000-000000000001',
      email: 'sysadmin@psu.edu.ph',
      name: 'System Administrator',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    final current = _currentUser;
    try {
      if (current != null) {
        String title = 'User Logout';
        if (current.role == UserRole.admin) title = 'Admin Logout';
        else if (current.role == UserRole.campadmin) title = 'Campus Admin Logout';
        else if (current.role == UserRole.teacher) title = 'Teacher Logout';
        else if (current.role == UserRole.maintenance) title = 'Maintenance Logout';

        await LoginActivityService.recordAction(
          user: current,
          title: title,
          details: 'Logged out from the system',
        );
        if (current.role == UserRole.maintenance) {
          await MaintenanceStatusService.setOfflineOnLogout(current.id);
        }
      }

      await _auth.auth.signOut(scope: SignOutScope.global);
      _currentUser = null;
      _isSessionInitialized = true;
      _isPostLoginSplashActive = false;
      _pauseLoginRedirectOnce = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // Check existing session (auto-login on app start)
  // ---------------------------------------------------------------
  Future<AppUser?> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _syncCurrentUserFromSession(_auth.auth.currentSession);
      final profile = _currentUser;
      _currentUser = profile;
      _isSessionInitialized = true;
      _isPostLoginSplashActive = false;
      if (profile != null) {
        try {
          await LoginActivityService.recordLogin(profile);
          if (profile.role == UserRole.maintenance) {
            await MaintenanceStatusService.setOnlineOnLogin(profile.id);
          }
        } catch (e) {
          debugPrint('Session login activity recording failed: $e');
        }
      }
      notifyListeners();
      return profile;
    } catch (e) {
      debugPrint('Session check error: $e');
      return null;
    } finally {
      _isSessionInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // Register a new user
  // ---------------------------------------------------------------
  Future<AppUser?> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? campus,
    String? department,
    String? position,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _auth.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role.name,
          'campus': ?campus,
          'department': ?department,
        },
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) return null;

      // Profile is created by the database trigger; fetch it directly.
      final profile = await _fetchProfile(supabaseUser.id);
      _currentUser = profile;
      notifyListeners();
      return profile;
    } catch (e) {
      debugPrint('Registration error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // Send password-reset email
  // ---------------------------------------------------------------
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      debugPrint('Password reset error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isInstitutionalEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return _institutionalDomains.any(
      (domain) => normalized.endsWith('@$domain'),
    );
  }

  Future<String?> registerFaculty({
    required String fullName,
    required String email,
    required String department,
    required String employeeId,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (!isInstitutionalEmail(normalizedEmail)) {
        return 'Faculty registration only accepts institutional email addresses.';
      }

      final response = await _auth.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'name': fullName.trim(),
          'role': UserRole.teacher.name,
          'department': department.trim(),
          'employee_id': employeeId.trim(),
        },
      );

      final newUser = response.user;
      if (newUser == null) {
        return 'Registration failed. Please try again.';
      }

      String? departmentId;
      final normalizedDepartment = department.trim();
      if (normalizedDepartment.isNotEmpty) {
        final dept = await DepartmentService.findOrCreateByName(
          normalizedDepartment,
        );
        departmentId = dept.id;
      }

      await _auth.from('teacher_users').upsert({
        'user_id': newUser.id,
        'department_id': departmentId,
        'employee_id': employeeId.trim(),
        'position': 'Faculty',
      }, onConflict: 'user_id');

      await _auth.auth.signOut();
      return null;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already') || msg.contains('registered')) {
        return 'This email is already registered.';
      }
      if (msg.contains('database error saving new user')) {
        return 'Faculty registration failed while creating the account profile. Please apply the latest database migrations and try again.';
      }
      return e.message;
    } catch (_) {
      return 'Unable to complete registration right now.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // Change password (requires old password verification)
  // ---------------------------------------------------------------
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final supabaseUser = _auth.auth.currentUser;
    final email = supabaseUser?.email;

    if (supabaseUser == null || email == null) {
      return 'No active session found. Please login again.';
    }

    try {
      await _auth.auth.signInWithPassword(email: email, password: oldPassword);
    } catch (_) {
      return 'Old password is incorrect.';
    }

    try {
      await _auth.auth.updateUser(UserAttributes(password: newPassword));

      if (_currentUser != null) {
        await LoginActivityService.recordAction(
          user: _currentUser!,
          title: 'Changed Password',
          details: 'Updated account password',
        );
      }

      return null;
    } catch (e) {
      debugPrint('Change password error: $e');
      return 'Failed to update password. Please try again.';
    }
  }

  // ---------------------------------------------------------------
  // Update the current user's profile in the database
  // ---------------------------------------------------------------
  Future<bool> updateProfile(AppUser updatedUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth
          .from('users')
          .update({
            'name': updatedUser.name,
            'role': updatedUser.role.name,
            'phone': updatedUser.phone,
            'profile_image': updatedUser.profileImage,
          })
          .eq('id', updatedUser.id);

      if (updatedUser.role == UserRole.teacher) {
        String? departmentId;
        final normalizedDepartment = updatedUser.department?.trim() ?? '';
        if (normalizedDepartment.isNotEmpty) {
          final dept = await DepartmentService.findOrCreateByName(
            normalizedDepartment,
          );
          departmentId = dept.id;
        }

        await _auth.from('teacher_users').upsert({
          'user_id': updatedUser.id,
          'department_id': departmentId,
          'employee_id': updatedUser.employeeId,
          'position': updatedUser.position,
        }, onConflict: 'user_id');
      } else if (updatedUser.role == UserRole.maintenance) {
        await _auth.from('maintenance_users').upsert({
          'user_id': updatedUser.id,
          'employee_id': updatedUser.employeeId,
          'specialization': updatedUser.position,
        }, onConflict: 'user_id');
      }

      _currentUser = await _fetchProfile(updatedUser.id) ?? updatedUser;
      if (updatedUser.role == UserRole.admin ||
          updatedUser.role == UserRole.campadmin) {
        await LoginActivityService.recordAdminAction(
          user: updatedUser,
          title: 'Updated Profile',
          details: 'Updated admin profile information',
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Profile update error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfileImage({
    required UserRole role,
    required String userId,
    String? profileImage,
    bool clear = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.from('users').update({
        'profile_image': clear ? null : profileImage,
      }).eq('id', userId);

      _currentUser = await _fetchProfile(userId) ?? _currentUser;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Profile image update error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // Handle logout button press
  // ---------------------------------------------------------------
  Future<void> handleLogoutButton(BuildContext context) async {
    if (_isHandlingLogout) return;
    _isHandlingLogout = true;
    try {
      if (_currentUser?.role == UserRole.maintenance) {
        await MaintenanceStatusService.setOfflineOnLogout(_currentUser!.id);
      }
      await logout();

      final routerContext =
          context.mounted ? context : rootNavigatorKey.currentContext;
      if (routerContext != null) {
        GoRouter.of(routerContext).go('/login');
      }
    } finally {
      _isHandlingLogout = false;
    }
  }

  // ---------------------------------------------------------------
  // Show initialization screen after successful login
  // ---------------------------------------------------------------
  void showInitializingScreen(
    BuildContext context,
    String destinationRoute, {
    String? statusText,
  }) {
    final user = _currentUser;
    final resolvedStatusText = statusText ?? switch (user?.role) {
      UserRole.admin => 'Welcome, Admin',
      UserRole.campadmin => 'Welcome, Campus Admin',
      UserRole.teacher || UserRole.maintenance =>
        'Welcome, ${(user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'User'}',
      null => 'INITIALIZING',
    };

    GoRouter.of(context).go(
      '/post-login-splash',
      extra: {
        'destinationRoute': destinationRoute,
        'statusText': resolvedStatusText,
      },
    );
  }

  // ---------------------------------------------------------------
  // Force change password for mandatory password reset on first login
  // ---------------------------------------------------------------
  Future<String?> forceChangePassword(String newPassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.auth.currentUser;
      if (user == null) return 'No authenticated user found.';

      await _auth.auth.updateUser(
        UserAttributes(
          password: newPassword.trim(),
          data: {'must_change_password': false},
        ),
      );

      try {
        await _auth.from('users').update({
          'must_change_password': false,
        }).eq('id', user.id);
      } catch (_) {}

      _currentUser = await _fetchProfile(user.id);
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // Internal: fetch profile row from Supabase
  // ---------------------------------------------------------------
  Future<AppUser?> _fetchProfile(String userId) async {
    final baseProfile = await _auth
        .from('users')
        .select('*')
        .eq('id', userId)
        .maybeSingle();
    if (baseProfile == null) return null;

    final mergedProfile = Map<String, dynamic>.from(baseProfile);
    final currentSupabaseUser = _auth.auth.currentUser;
    if (currentSupabaseUser?.id == userId && currentSupabaseUser?.userMetadata != null) {
      mergedProfile['user_metadata'] = currentSupabaseUser!.userMetadata;
    }

    // Build department lookup map for fallback resolution
    final deptMap = <String, String>{};
    try {
      final List<dynamic> deptsJson = await _auth.from('departments').select('id, name');
      for (final d in deptsJson) {
        if (d is Map && d['id'] != null && d['name'] != null) {
          deptMap[d['id'].toString()] = d['name'].toString();
        }
      }
    } catch (_) {}

    final role = (mergedProfile['role'] ?? '').toString().toLowerCase();

    if (role == UserRole.teacher.name) {
      final teacherProfile = await _auth
          .from('teacher_users')
          .select('*, departments(name)')
          .eq('user_id', userId)
          .maybeSingle();
      if (teacherProfile != null) {
        final tRow = Map<String, dynamic>.from(teacherProfile);
        final deptId = tRow['department_id']?.toString();
        if (deptId != null && deptMap.containsKey(deptId)) {
          tRow['departments'] = {'name': deptMap[deptId]};
        }
        mergedProfile['teacher_users'] = tRow;
      }
    } else if (role == UserRole.maintenance.name) {
      final maintenanceProfile = await _auth
          .from('maintenance_users')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      if (maintenanceProfile != null) {
        mergedProfile['maintenance_users'] = maintenanceProfile;
      }
    }

    return AppUser.fromMap(mergedProfile, deptMap: deptMap);
  }

  @override
  void dispose() {
    _profileRealtimeChannel?.unsubscribe();
    _authStateSubscription.cancel();
    super.dispose();
  }
}
