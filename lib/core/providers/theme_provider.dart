import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme provider that persists dark/light mode preference across app restarts.
class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'dark_mode';

  bool _isDarkMode = false;

  ThemeProvider() {
    _loadFromPrefs();
  }

  bool get isDarkMode => _isDarkMode;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey) ?? false;
      if (saved != _isDarkMode) {
        _isDarkMode = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, _isDarkMode);
    } catch (_) {}
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }
}
