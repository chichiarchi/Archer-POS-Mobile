import 'package:flutter/foundation.dart';

/// A simple theme provider for future dark/light mode support.
///
/// Currently holds a single [isDarkMode] flag (always false by default).
/// Call [toggleTheme] to flip between modes.
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  /// Whether the app is currently in dark mode.
  bool get isDarkMode => _isDarkMode;

  /// Toggles between dark and light mode.
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  /// Explicitly sets the dark mode state.
  void setDarkMode(bool value) {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
  }
}
