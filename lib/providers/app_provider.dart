import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _currency = '₹';

  ThemeMode get themeMode => _themeMode;
  String get currency => _currency;

  AppProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIdx = prefs.getInt('themeMode');
    if (themeIdx != null) {
      _themeMode = ThemeMode.values[themeIdx];
    }
    _currency = prefs.getString('currency') ?? '₹';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> setCurrency(String newCurrency) async {
    _currency = newCurrency;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', newCurrency);
  }
}
