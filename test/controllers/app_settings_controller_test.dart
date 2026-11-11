import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronuncia/controllers/app_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('restaura el tema y la velocidad de voz guardados', () async {
    final settings = AppSettingsController();
    await settings.load();
    await settings.setThemeMode(ThemeMode.dark);
    await settings.setSpeechRate(0.6);

    final restored = AppSettingsController();
    await restored.load();

    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.speechRate, 0.6);
    settings.dispose();
    restored.dispose();
  });

  test('rechaza velocidades de voz fuera del intervalo permitido', () async {
    final settings = AppSettingsController();
    await settings.load();

    await expectLater(settings.setSpeechRate(1), throwsArgumentError);
    settings.dispose();
  });
}
