import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/app_settings_controller.dart';
import 'controllers/demo_study_controller.dart';
import 'data/database_helper.dart';
import 'views/home_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, this.databaseHelper, this.studyController});

  final DatabaseHelper? databaseHelper;
  final DemoStudyController? studyController;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final AppSettingsController _settingsController =
      AppSettingsController();
  late final Future<void> _settingsLoad = _settingsController.load();

  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF2E7055);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsController>.value(
          value: _settingsController,
        ),
        ChangeNotifierProvider<DemoStudyController>(
          create: (_) {
            final controller =
                widget.studyController ??
                DemoStudyController(databaseHelper: widget.databaseHelper);
            if (widget.studyController == null) {
              unawaited(controller.cargar());
            }
            return controller;
          },
        ),
      ],
      child: FutureBuilder<void>(
        future: _settingsLoad,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudieron cargar los ajustes: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: ColorScheme.fromSeed(seedColor: seedColor).primary,
                  ),
                ),
              ),
            );
          }

          return AnimatedBuilder(
            animation: _settingsController,
            builder: (context, _) => MaterialApp(
              title: 'Pronuncia',
              debugShowCheckedModeBanner: false,
              theme: _buildTheme(seedColor, Brightness.light),
              darkTheme: _buildTheme(seedColor, Brightness.dark),
              themeMode: _settingsController.themeMode,
              home: const HomeScreen(),
            ),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Color seedColor, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: colorScheme.primary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(color: colorScheme.surfaceContainerLow),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
