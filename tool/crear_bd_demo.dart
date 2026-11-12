import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pronuncia/data/database_helper.dart';
import 'package:pronuncia/data/intento_repository.dart';
import 'package:pronuncia/data/palabra_repository.dart';
import 'package:pronuncia/data/tema_repository.dart';
import 'package:pronuncia/models/intento.dart';
import 'package:pronuncia/models/tema.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length > 1) {
    throw ArgumentError('Uso: dart run tool/crear_bd_demo.dart [ruta.db]');
  }

  final databasePath = path.absolute(
    arguments.isEmpty
        ? path.join('evidencias', 'db-browser', 'pronuncia-demo-v5.db')
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

    final catalogo = await temas.obtenerTodos();
    final animales = catalogo.singleWhere((tema) => tema.nombre == 'Animales');
    final comida = catalogo.singleWhere((tema) => tema.nombre == 'Comida');
    final animalesId = animales.id!;
    final comidaId = comida.id!;
    await temas.crear(const Tema(nombre: 'Viajes sin intentos'));

    final palabrasAnimales = await palabras.obtenerPorTema(animalesId);
    final palabrasComida = await palabras.obtenerPorTema(comidaId);
    final gatoId = palabrasAnimales
        .singleWhere((palabra) => palabra.ingles.toLowerCase() == 'cat')
        .id!;
    final perroId = palabrasAnimales
        .singleWhere((palabra) => palabra.ingles.toLowerCase() == 'dog')
        .id!;
    final manzanaId = palabrasComida
        .singleWhere((palabra) => palabra.ingles.toLowerCase() == 'apple')
        .id!;

    final fecha = DateTime.utc(2026, 11, 10);
    final List<(int, bool, String, String?, int?)> ejemplos = [
      (gatoId, false, 'voz', 'kat', null),
      (gatoId, false, 'voz', 'cut', null),
      (gatoId, true, 'voz', 'cat', null),
      (gatoId, true, 'pronunciacion', 'cat', 100),
      (perroId, true, 'tarjetas', null, null),
      (manzanaId, false, 'pose', null, null),
      (manzanaId, true, 'dedos', null, null),
    ];
    for (var index = 0; index < ejemplos.length; index++) {
      final (palabraId, acierto, origen, textoReconocido, puntuacion) =
          ejemplos[index];
      await intentos.crear(
        Intento(
          palabraId: palabraId,
          fecha: fecha.add(Duration(minutes: index)),
          acierto: acierto,
          origen: origen,
          textoReconocido: textoReconocido,
          puntuacion: puntuacion,
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
