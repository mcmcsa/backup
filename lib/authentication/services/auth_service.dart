import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../../shared/services/login_activity_service.dart';
import '../../shared/widgets/loading_screen.dart';
import '../screens/login_page.dart';

class AuthService extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _loginError;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get loginError => _loginError;

  static SupabaseClient get _auth => Supabase.instance.client;

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

      final profile = await _fetchProfile(supabaseUser.id);
      if (profile == null) {
        _loginError = 'Login succeeded but no profile found. Contact an admin.';
        return null;
      }
      _currentUser = profile;
      await LoginActivityService.recordLogin(profile);
      notifyListeners();
      return profile;
    } catch (e) {
      debugPrint('Login error: $e');
      _loginError = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.auth.signOut();
      _currentUser = null;
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
      final supabaseUser = _auth.auth.currentUser;
      if (supabaseUser == null) return null;

      final profile = await _fetchProfile(supabaseUser.id);
      _currentUser = profile;
      if (profile != null) {
        await LoginActivityService.recordLogin(profile);
      }
      notifyListeners();
      return profile;
    } catch (e) {
      debugPrint('Session check error: $e');
      return null;
    } finally {
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
          'position': ?position,
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

  // ---------------------------------------------------------------
  // Update the current user's profile in the database
  // ---------------------------------------------------------------
  Future<bool> updateProfile(AppUser updatedUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.from('users').update({
        'name': updatedUser.name,
        'role': updatedUser.role.name,
        'campus': updatedUser.campus,
        'department_id': updatedUser.department,
        'position': updatedUser.position,
        'profile_image': updatedUser.profileImage,
      }).eq('id', updatedUser.id);

      _currentUser = updatedUser;
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

  // ---------------------------------------------------------------
  // Handle logout button press
  // ---------------------------------------------------------------
  Future<void> handleLogoutButton(BuildContext context) async {
    await logout();

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoadingScreen(
            destination: const LoginPage(),
            instant: true,
            statusText: 'LOGGING OUT',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------
  // Show initialization screen after successful login
  // ---------------------------------------------------------------
  void showInitializingScreen(BuildContext context, Widget destination) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoadingScreen(
          destination: destination,
          delay: const Duration(seconds: 4),
          statusText: 'INITIALIZING',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Internal: fetch profile row from Supabase
  // ---------------------------------------------------------------
  Future<AppUser?> _fetchProfile(String userId) async {
    final data = await _auth
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return AppUser.fromMap(data);
  }
}

