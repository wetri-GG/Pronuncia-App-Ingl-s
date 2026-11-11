import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsController extends ChangeNotifier {
  static const _themeModeKey = 'theme_mode';
  static const _speechRateKey = 'speech_rate';

  ThemeMode _themeMode = ThemeMode.system;
  double _speechRate = 0.45;
  Future<SharedPreferences>? _preferences;

  ThemeMode get themeMode => _themeMode;
  double get speechRate => _speechRate;

  Future<void> load() async {
    final preferences = await _getPreferences();
    _themeMode = switch (preferences.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _speechRate = preferences.getDouble(_speechRateKey) ?? 0.45;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final saved = await (await _getPreferences()).setString(
      _themeModeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
    if (!saved) throw StateError('No se pudo guardar el modo de apariencia.');
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    if (!rate.isFinite || rate < 0.2 || rate > 0.8) {
      throw ArgumentError.value(rate, 'rate', 'Debe estar entre 0.2 y 0.8.');
    }
    final saved = await (await _getPreferences()).setDouble(
      _speechRateKey,
      rate,
    );
    if (!saved) throw StateError('No se pudo guardar la velocidad de voz.');
    _speechRate = rate;
    notifyListeners();
  }

  Future<SharedPreferences> _getPreferences() =>
      _preferences ??= SharedPreferences.getInstance();
}
