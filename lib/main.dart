import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/demo_study_controller.dart';
import 'data/database_helper.dart';
import 'views/home_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, this.databaseHelper, this.studyController});

  final DatabaseHelper? databaseHelper;
  final DemoStudyController? studyController;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF2E7055);

    return ChangeNotifierProvider<DemoStudyController>(
      create: (_) {
        final controller =
            studyController ??
            DemoStudyController(databaseHelper: databaseHelper);
        if (studyController == null) {
          unawaited(controller.cargar());
        }
        return controller;
      },
      child: MaterialApp(
        title: 'Pronuncia',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor,
            surface: const Color(0xFFF7F9F8),
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F9F8),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF7F9F8),
            foregroundColor: Color(0xFF214F3C),
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: TextStyle(
              color: Color(0xFF214F3C),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
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
              foregroundColor: seedColor,
              side: const BorderSide(color: Color(0xFFDCE8E1)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
