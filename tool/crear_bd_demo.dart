import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pronuncia/data/database_helper.dart';
import 'package:pronuncia/data/intento_repository.dart';
import 'package:pronuncia/data/palabra_repository.dart';
import 'package:pronuncia/data/tema_repository.dart';
import 'package:pronuncia/models/intento.dart';
import 'package:pronuncia/models/palabra.dart';
import 'package:pronuncia/models/tema.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length > 1) {
    throw ArgumentError('Uso: dart run tool/crear_bd_demo.dart [ruta.db]');
  }

  final databasePath = path.absolute(
    arguments.isEmpty
        ? path.join('evidencias', 'db-browser', 'pronuncia-demo.db')
        : arguments.single,
  );
  final databaseFile = File(databasePath);
  if (await databaseFile.exists()) {
    throw StateError('La base ya existe y no se sobrescribira: $databasePath');
  }
  await databaseFile.parent.create(recursive: true);

  final databaseHelper = DatabaseHelper(databasePath: databasePath);
  try {
    final temas = TemaRepository(databaseHelper);
    final palabras = PalabraRepository(databaseHelper);
    final intentos = IntentoRepository(databaseHelper);

    final animalesId = await temas.crear(const Tema(nombre: 'Animales'));
    final comidaId = await temas.crear(const Tema(nombre: 'Comida'));
    await temas.crear(const Tema(nombre: 'Viajes sin intentos'));

    final gatoId = await palabras.crear(
      Palabra(temaId: animalesId, ingles: 'cat', espanol: 'gato'),
    );
    final perroId = await palabras.crear(
      Palabra(temaId: animalesId, ingles: 'dog', espanol: 'perro'),
    );
    final manzanaId = await palabras.crear(
      Palabra(temaId: comidaId, ingles: 'apple', espanol: 'manzana'),
    );

    final fecha = DateTime.utc(2026, 11, 10);
    final List<(int, bool, String, String?)> ejemplos = [
      (gatoId, false, 'voz', 'kat'),
      (gatoId, false, 'voz', 'cut'),
      (gatoId, true, 'voz', 'cat'),
      (perroId, true, 'tarjetas', null),
      (manzanaId, false, 'pose', null),
      (manzanaId, true, 'dedos', null),
    ];
    for (var index = 0; index < ejemplos.length; index++) {
      final (palabraId, acierto, origen, textoReconocido) = ejemplos[index];
      await intentos.crear(
        Intento(
          palabraId: palabraId,
          fecha: fecha.add(Duration(minutes: index)),
          acierto: acierto,
          origen: origen,
          textoReconocido: textoReconocido,
        ),
      );
    }

    stdout.writeln('Base de demostracion creada: $databasePath');
    stdout.writeln(
      'Incluye datos sinteticos de temas, palabras e intentos NUI.',
    );
  } finally {
    await databaseHelper.close();
  }
}
