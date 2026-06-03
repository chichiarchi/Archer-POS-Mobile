import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

class AuthProvider extends ChangeNotifier {
  String? _username;
  String? _role;
  bool _isLoading = false;
  String? _error;

  String? get username => _username;
  String? get role => _role;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _username != null;

  /// Attempts to log in with the given [username] and [password].
  /// Calls [DatabaseHelper.instance.verifyLogin] and updates state accordingly.
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await DatabaseHelper.instance.verifyLogin(username, password);

      if (user != null) {
        _username = user['username'] as String?;
        _role = user['role'] as String?;
        _isLoading = false;
        _error = null;
        notifyListeners();

        // Log the login action
        await DatabaseHelper.instance.logAction(
          'LOGIN',
          details: 'User logged in with role: $_role',
          userId: _username ?? username,
        );

        return true;
      } else {
        _isLoading = false;
        _error = 'Invalid username or password.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'An error occurred during login: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Logs out the current user, clears all auth state.
  Future<void> logout() async {
    if (_username != null) {
      try {
        await DatabaseHelper.instance.logAction(
          'LOGOUT',
          details: 'User logged out.',
          userId: _username!,
        );
      } catch (_) {
        // Swallow errors during logout logging
      }
    }

    _username = null;
    _role = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Clears any existing error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Returns true if the current user has admin or owner role.
  bool get isAdmin =>
      _role == 'admin' || _role == 'owner' || _role == 'Administrator';

  /// Returns true if the current user has cashier role.
  bool get isCashier => _role == 'cashier' || _role == 'Cashier';
}
