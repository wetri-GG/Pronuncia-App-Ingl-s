import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pronuncia/data/database_helper.dart';
import 'package:pronuncia/data/intento_repository.dart';
import 'package:pronuncia/data/palabra_repository.dart';
import 'package:pronuncia/data/tema_repository.dart';
import 'package:pronuncia/models/intento.dart';
import 'package:pronuncia/models/palabra.dart';
import 'package:pronuncia/models/tema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directorioTemporal;
  late DatabaseHelper databaseHelper;
  late TemaRepository temaRepository;
  late PalabraRepository palabraRepository;
  late IntentoRepository intentoRepository;

  setUp(() async {
    directorioTemporal = await Directory.systemTemp.createTemp(
      'pronuncia-db-test-',
    );
    databaseHelper = DatabaseHelper(
      databasePath: join(directorioTemporal.path, 'test.db'),
    );
    temaRepository = TemaRepository(databaseHelper);
    palabraRepository = PalabraRepository(databaseHelper);
    intentoRepository = IntentoRepository(databaseHelper);
    await databaseHelper.database;
    for (final tema in await temaRepository.obtenerTodos()) {
      await temaRepository.eliminar(tema.id!);
    }
  });

  tearDown(() async {
    await databaseHelper.close();
    await directorioTemporal.delete(recursive: true);
  });

  test('los repositorios completan CRUD y filtran por relacion', () async {
    final temaId = await temaRepository.crear(const Tema(nombre: 'Animales'));
    final otroTemaId = await temaRepository.crear(const Tema(nombre: 'Comida'));
    final palabraId = await palabraRepository.crear(
      Palabra(temaId: temaId, ingles: 'cat', espanol: 'gato'),
    );
    final otraPalabraId = await palabraRepository.crear(
      Palabra(temaId: otroTemaId, ingles: 'bread', espanol: 'pan'),
    );
    final fecha = DateTime.utc(2026, 10, 28, 17);
    final intentoId = await intentoRepository.crear(
      Intento(
        palabraId: palabraId,
        fecha: fecha,
        acierto: true,
        textoReconocido: 'cat',
        origen: 'voz',
      ),
    );

    expect((await temaRepository.obtenerPorId(temaId))?.nombre, 'Animales');
    expect((await temaRepository.obtenerTodos()).length, 2);
    expect((await palabraRepository.obtenerPorId(palabraId))?.ingles, 'cat');
    expect(
      (await palabraRepository.obtenerPorTema(temaId))
          .map((palabra) => palabra.id),
      [palabraId],
    );
    expect(
      (await palabraRepository.obtenerTodos()).map((palabra) => palabra.id),
      [palabraId, otraPalabraId],
    );
    expect((await intentoRepository.obtenerPorId(intentoId))?.fecha, fecha);
    expect((await intentoRepository.obtenerPorId(intentoId))?.origen, 'voz');
    expect(
      (await intentoRepository.obtenerPorPalabra(palabraId)),
      hasLength(1),
    );

    expect(
      await temaRepository.actualizar(
        Tema(id: temaId, nombre: 'Animales domésticos'),
      ),
      1,
    );
    expect(
      (await temaRepository.obtenerPorId(temaId))?.nombre,
      'Animales domésticos',
    );
    expect(
      await palabraRepository.actualizar(
        Palabra(id: palabraId, temaId: temaId, ingles: 'dog', espanol: 'perro'),
      ),
      1,
    );
    expect((await palabraRepository.obtenerPorId(palabraId))?.ingles, 'dog');
    expect(
      await intentoRepository.actualizar(
        Intento(
          id: intentoId,
          palabraId: palabraId,
          fecha: fecha,
          acierto: false,
          textoReconocido: 'wrong',
        ),
      ),
      1,
    );
    expect((await intentoRepository.obtenerPorId(intentoId))?.acierto, isFalse);

    expect(await intentoRepository.eliminar(intentoId), 1);
    expect(await palabraRepository.eliminar(palabraId), 1);
    expect(await temaRepository.eliminar(temaId), 1);
    expect(await intentoRepository.obtenerPorId(intentoId), isNull);
    expect(await palabraRepository.obtenerPorId(palabraId), isNull);
    expect(await temaRepository.obtenerPorId(temaId), isNull);
  });

  test(
    'eliminar un tema elimina sus palabras e intentos relacionados',
    () async {
      final temaId = await temaRepository.crear(const Tema(nombre: 'Animales'));
      final palabraId = await palabraRepository.crear(
        Palabra(temaId: temaId, ingles: 'cat', espanol: 'gato'),
      );
      final intentoId = await intentoRepository.crear(
        Intento(palabraId: palabraId, fecha: DateTime.utc(2026), acierto: true),
      );

      expect(await temaRepository.eliminar(temaId), 1);
      expect(await palabraRepository.obtenerPorId(palabraId), isNull);
      expect(await intentoRepository.obtenerPorId(intentoId), isNull);
    },
  );

  test('actualizar requiere un id', () async {
    expect(
      () => temaRepository.actualizar(const Tema(nombre: 'Sin id')),
      throwsArgumentError,
    );
    expect(
      () => palabraRepository.actualizar(
        const Palabra(temaId: 1, ingles: 'cat', espanol: 'gato'),
      ),
      throwsArgumentError,
    );
    expect(
      () => intentoRepository.actualizar(
        Intento(palabraId: 1, fecha: DateTime.utc(2026), acierto: true),
      ),
      throwsArgumentError,
    );
  });

  test(
    'las consultas agregadas relacionan intentos, palabras y temas',
    () async {
      final animalesId = await temaRepository.crear(
        const Tema(nombre: 'Animales'),
      );
      final sinIntentosId = await temaRepository.crear(
        const Tema(nombre: 'Sin intentos'),
      );
      final gatoId = await palabraRepository.crear(
        Palabra(temaId: animalesId, ingles: 'cat', espanol: 'gato'),
      );
      final perroId = await palabraRepository.crear(
        Palabra(temaId: animalesId, ingles: 'dog', espanol: 'perro'),
      );

      for (final (palabraId, acierto) in [
        (gatoId, false),
        (gatoId, false),
        (gatoId, true),
        (perroId, false),
        (perroId, true),
      ]) {
        await intentoRepository.crear(
          Intento(
            palabraId: palabraId,
            fecha: DateTime.utc(2026, 11, 1),
            acierto: acierto,
          ),
        );
      }

      final estadisticas = await intentoRepository.obtenerEstadisticasPorTema();
      expect(estadisticas, [
        (temaId: animalesId, intentos: 5, aciertos: 2),
        (temaId: sinIntentosId, intentos: 0, aciertos: 0),
      ]);

      final palabrasFalladas = await intentoRepository
          .obtenerPalabrasMasFalladas(limite: 1);
      expect(palabrasFalladas, hasLength(1));
      expect(palabrasFalladas.single.palabra.ingles, 'cat');
      expect(palabrasFalladas.single.fallos, 2);
      expect(
        () => intentoRepository.obtenerPalabrasMasFalladas(limite: 0),
        throwsArgumentError,
      );
    },
  );

  test('la migracion conserva intentos de una base version 1', () async {
    final oldDatabasePath = join(directorioTemporal.path, 'old-version.db');
    final oldDatabase = await databaseFactoryFfi.openDatabase(
      oldDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE temas (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)',
          );
          await db.execute('''
            CREATE TABLE palabras (
              id INTEGER PRIMARY KEY,
              tema_id INTEGER NOT NULL,
              ingles TEXT NOT NULL,
              espanol TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE intentos (
              id INTEGER PRIMARY KEY,
              palabra_id INTEGER NOT NULL,
              fecha TEXT NOT NULL,
              acierto INTEGER NOT NULL,
              texto_reconocido TEXT
            )
          ''');
          await db.insert('temas', {'id': 1, 'nombre': 'Animales'});
          await db.insert('palabras', {
            'id': 1,
            'tema_id': 1,
            'ingles': 'dog',
            'espanol': 'perro',
          });
          await db.insert('intentos', {
            'id': 1,
            'palabra_id': 1,
            'fecha': DateTime.utc(2026).toIso8601String(),
            'acierto': 1,
            'texto_reconocido': null,
          });
        },
      ),
    );
    await oldDatabase.close();

    final migratedHelper = DatabaseHelper(databasePath: oldDatabasePath);
    final migratedAttempts = await IntentoRepository(migratedHelper)
        .obtenerTodos();

    expect(migratedAttempts, hasLength(1));
    expect(migratedAttempts.single.acierto, isTrue);
    expect(migratedAttempts.single.origen, 'tarjetas');
    await migratedHelper.close();
  });

  test('la migracion elimina datos de ejemplo y conserva actividad real', () async {
    final oldDatabasePath = join(directorioTemporal.path, 'seeded-version.db');
    final oldDatabase = await databaseFactoryFfi.openDatabase(
      oldDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE temas (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL)',
          );
          await db.execute('''
            CREATE TABLE palabras (
              id INTEGER PRIMARY KEY,
              tema_id INTEGER NOT NULL,
              ingles TEXT NOT NULL,
              espanol TEXT NOT NULL,
              FOREIGN KEY (tema_id) REFERENCES temas(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE intentos (
              id INTEGER PRIMARY KEY,
              palabra_id INTEGER NOT NULL,
              fecha TEXT NOT NULL,
              acierto INTEGER NOT NULL,
              texto_reconocido TEXT,
              origen TEXT NOT NULL DEFAULT 'tarjetas',
              FOREIGN KEY (palabra_id) REFERENCES palabras(id) ON DELETE CASCADE
            )
          ''');
          await db.insert('temas', {'id': 1, 'nombre': 'Animales'});
          await db.insert('palabras', {
            'id': 1,
            'tema_id': 1,
            'ingles': 'Dog',
            'espanol': 'Perro',
          });
          await db.insert('palabras', {
            'id': 2,
            'tema_id': 1,
            'ingles': 'Cat',
            'espanol': 'Gato',
          });
          await db.insert('intentos', {
            'id': 1,
            'palabra_id': 1,
            'fecha': DateTime(2026, 10, 28).toIso8601String(),
            'acierto': 1,
            'texto_reconocido': null,
            'origen': 'tarjetas',
          });
          await db.insert('intentos', {
            'id': 2,
            'palabra_id': 2,
            'fecha': DateTime(2026, 10, 28).toIso8601String(),
            'acierto': 1,
            'texto_reconocido': null,
            'origen': 'tarjetas',
          });
          await db.insert('intentos', {
            'id': 3,
            'palabra_id': 1,
            'fecha': DateTime.utc(2026, 11, 10).toIso8601String(),
            'acierto': 1,
            'texto_reconocido': 'dog',
            'origen': 'voz',
          });
        },
      ),
    );
    await oldDatabase.close();

    final migratedHelper = DatabaseHelper(databasePath: oldDatabasePath);
    final migratedTopics = await TemaRepository(migratedHelper).obtenerTodos();
    final migratedWords = await PalabraRepository(migratedHelper)
        .obtenerTodos();
    final migratedAttempts = await IntentoRepository(migratedHelper)
        .obtenerTodos();

    expect(migratedTopics.map((topic) => topic.nombre), [
      'Animales',
      'Colores',
      'Comida',
      'Números',
      'Simon Says',
    ]);
    expect(migratedWords, hasLength(24));
    expect(migratedWords.where((word) => word.ingles == 'Dog'), hasLength(1));
    expect(migratedWords.where((word) => word.ingles == 'Cat'), hasLength(1));
    expect(migratedAttempts, hasLength(1));
    expect(migratedAttempts.single.origen, 'voz');
    expect(migratedAttempts.single.textoReconocido, 'dog');
    await migratedHelper.close();
  });
}
