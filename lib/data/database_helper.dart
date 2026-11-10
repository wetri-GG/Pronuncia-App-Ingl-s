import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  DatabaseHelper({this.databasePath});

  static final DatabaseHelper instance = DatabaseHelper();
  static bool _ffiFactoryConfigured = false;

  static const _databaseName = 'pronuncia.db';
  static const _databaseVersion = 4;
  static const _defaultCatalog = {
    'Animales': {
      'Dog': 'Perro',
      'Cat': 'Gato',
      'Bird': 'Pajaro',
      'Fish': 'Pez',
    },
    'Comida': {'Apple': 'Manzana', 'Bread': 'Pan', 'Water': 'Agua'},
    'Colores': {'Green': 'Verde', 'Blue': 'Azul', 'Red': 'Rojo'},
    'Números': {
      'Zero': 'Cero',
      'One': 'Uno',
      'Two': 'Dos',
      'Three': 'Tres',
      'Four': 'Cuatro',
      'Five': 'Cinco',
      'Six': 'Seis',
      'Seven': 'Siete',
      'Eight': 'Ocho',
      'Nine': 'Nueve',
      'Ten': 'Diez',
    },
    'Simon Says': {
      'Arms up': 'Brazos arriba',
      'Left arm': 'Brazo izquierdo',
      'Right arm': 'Brazo derecho',
    },
  };

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
            origen TEXT NOT NULL DEFAULT 'tarjetas',
            FOREIGN KEY (palabra_id) REFERENCES palabras(id) ON DELETE CASCADE
          )
        ''');
        await _insertDefaultCatalog(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE intentos ADD COLUMN origen TEXT NOT NULL DEFAULT 'tarjetas'",
          );
        }
        if (oldVersion < 3) {
          await _removeLegacyDemoData(db);
        }
        if (oldVersion < 4) {
          await _insertDefaultCatalog(db);
        }
      },
    );
  }

  Future<void> _insertDefaultCatalog(Database db) async {
    for (final entry in _defaultCatalog.entries) {
      final existingTopics = await db.query(
        'temas',
        columns: ['id'],
        where: 'nombre = ?',
        whereArgs: [entry.key],
        limit: 1,
      );
      final topicId = existingTopics.isEmpty
          ? await db.insert('temas', {'nombre': entry.key})
          : existingTopics.first['id'] as int;

      for (final word in entry.value.entries) {
        final existingWords = await db.query(
          'palabras',
          columns: ['id'],
          where: 'tema_id = ? AND ingles = ?',
          whereArgs: [topicId, word.key],
          limit: 1,
        );
        if (existingWords.isEmpty) {
          await db.insert('palabras', {
            'tema_id': topicId,
            'ingles': word.key,
            'espanol': word.value,
          });
        }
      }
    }
  }

  Future<void> _removeLegacyDemoData(Database db) async {
    final seedDates = List.generate(
      5,
      (index) => DateTime(
        2026,
        10,
        28,
      ).subtract(Duration(days: index)).toIso8601String(),
    );
    final topics = await db.query('temas');
    for (final topic in topics) {
      final topicName = topic['nombre'] as String;
      final words = _defaultCatalog[topicName];
      if (words == null) continue;

      final topicId = topic['id'] as int;
      final storedWords = await db.query(
        'palabras',
        where: 'tema_id = ?',
        whereArgs: [topicId],
      );
      for (final word in storedWords) {
        final translation = words[word['ingles']];
        if (translation == null || translation != word['espanol']) continue;

        final wordId = word['id'] as int;
        await db.delete(
          'intentos',
          where:
              "palabra_id = ? AND fecha IN (${List.filled(seedDates.length, '?').join(',')}) AND origen = 'tarjetas' AND texto_reconocido IS NULL",
          whereArgs: [wordId, ...seedDates],
        );
        final remainingAttempts = await db.query(
          'intentos',
          columns: ['id'],
          where: 'palabra_id = ?',
          whereArgs: [wordId],
          limit: 1,
        );
        if (remainingAttempts.isEmpty) {
          await db.delete('palabras', where: 'id = ?', whereArgs: [wordId]);
        }
      }

      final remainingWords = await db.query(
        'palabras',
        columns: ['id'],
        where: 'tema_id = ?',
        whereArgs: [topicId],
        limit: 1,
      );
      if (remainingWords.isEmpty) {
        await db.delete('temas', where: 'id = ?', whereArgs: [topicId]);
      }
    }
  }

  Future<void> close() async {
    final databaseFuture = _database;
    if (databaseFuture != null) {
      await (await databaseFuture).close();
      _database = null;
    }
  }
}
