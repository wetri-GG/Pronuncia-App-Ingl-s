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
}
