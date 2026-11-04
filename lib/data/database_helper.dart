import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  DatabaseHelper({this.databasePath});

  static final DatabaseHelper instance = DatabaseHelper();
  static bool _ffiFactoryConfigured = false;

  static const _databaseName = 'pronuncia.db';
  static const _databaseVersion = 1;

  final String? databasePath;
  Future<Database>? _database;

  Future<Database> get database => _database ??= _openDatabase();

  Future<Database> _openDatabase() async {
    if (!_ffiFactoryConfigured &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiFactoryConfigured = true;
    }

    final path = databasePath ?? join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE temas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE palabras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tema_id INTEGER NOT NULL,
            ingles TEXT NOT NULL,
            espanol TEXT NOT NULL,
            FOREIGN KEY (tema_id) REFERENCES temas(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE intentos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            palabra_id INTEGER NOT NULL,
            fecha TEXT NOT NULL,
            acierto INTEGER NOT NULL,
            texto_reconocido TEXT,
            FOREIGN KEY (palabra_id) REFERENCES palabras(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    final databaseFuture = _database;
    if (databaseFuture != null) {
      await (await databaseFuture).close();
      _database = null;
    }
  }
}
