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
}
