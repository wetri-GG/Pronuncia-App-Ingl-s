import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../data/intento_repository.dart';
import '../data/palabra_repository.dart';
import '../data/tema_repository.dart';
import '../models/intento.dart';
import '../models/palabra.dart';
import '../models/tema.dart';

class DemoStudyController extends ChangeNotifier {
  DemoStudyController({
    DatabaseHelper? databaseHelper,
    TemaRepository? temaRepository,
    PalabraRepository? palabraRepository,
    IntentoRepository? intentoRepository,
  }) : _temaRepository = temaRepository ?? TemaRepository(databaseHelper),
       _palabraRepository =
           palabraRepository ?? PalabraRepository(databaseHelper),
       _intentoRepository =
           intentoRepository ?? IntentoRepository(databaseHelper);

  final TemaRepository _temaRepository;
  final PalabraRepository _palabraRepository;
  final IntentoRepository _intentoRepository;

  List<Tema> _temas = [];
  final Map<int, List<Palabra>> _palabrasPorTema = {};
  final Map<int, List<Intento>> _intentosPorTema = {};
  bool isLoading = false;
  Object? error;

  List<Tema> get temas => List.unmodifiable(_temas);

  List<Palabra> palabrasDe(Tema tema) =>
      List.unmodifiable(_palabrasPorTema[tema.id] ?? const []);

  int porcentajeAcierto(Tema tema) {
    final intentos = _intentosPorTema[tema.id] ?? const [];
    if (intentos.isEmpty) return 0;

    final aciertos = intentos.where((intento) => intento.acierto).length;
    return (aciertos * 100 / intentos.length).round();
  }

  Future<void> cargar() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      var temas = await _temaRepository.obtenerTodos();
      if (temas.isEmpty) {
        await _crearDatosIniciales();
        temas = await _temaRepository.obtenerTodos();
      }

      final palabras = await _palabraRepository.obtenerTodos();
      final intentos = await _intentoRepository.obtenerTodos();

      _temas = temas;
      _palabrasPorTema
        ..clear()
        ..addEntries(temas.map((tema) => MapEntry(tema.id!, <Palabra>[])));
      for (final palabra in palabras) {
        _palabrasPorTema[palabra.temaId]?.add(palabra);
      }

      _intentosPorTema
        ..clear()
        ..addEntries(temas.map((tema) => MapEntry(tema.id!, <Intento>[])));
      final temaIdPorPalabra = {
        for (final palabra in palabras) palabra.id!: palabra.temaId,
      };
      for (final intento in intentos) {
        final temaId = temaIdPorPalabra[intento.palabraId];
        _intentosPorTema[temaId]?.add(intento);
      }
    } catch (exception) {
      error = exception;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> agregarTema(String nombre) async {
    final id = await _temaRepository.crear(Tema(nombre: nombre.trim()));
    final tema = Tema(id: id, nombre: nombre.trim());
    _temas = [..._temas, tema];
    _palabrasPorTema[id] = [];
    _intentosPorTema[id] = [];
    notifyListeners();
  }

  Future<void> registrarRespuesta(
    Palabra palabra, {
    required bool conocida,
  }) async {
    final palabraId = palabra.id;
    if (palabraId == null) {
      throw ArgumentError(
        'No se puede registrar un intento sin id de palabra.',
      );
    }

    final intento = Intento(
      palabraId: palabraId,
      fecha: DateTime.now(),
      acierto: conocida,
    );
    final id = await _intentoRepository.crear(intento);
    final intentos = _intentosPorTema[palabra.temaId];
    if (intentos == null) {
      throw StateError('No se encontró el tema de la palabra.');
    }
    intentos.add(
      Intento(
        id: id,
        palabraId: intento.palabraId,
        fecha: intento.fecha,
        acierto: intento.acierto,
      ),
    );
    notifyListeners();
  }

  Future<void> _crearDatosIniciales() async {
    await _crearTemaInicial('Animales', const [
      ('Dog', 'Perro'),
      ('Cat', 'Gato'),
      ('Bird', 'Pajaro'),
      ('Fish', 'Pez'),
    ], correctAnswers: 4);
    await _crearTemaInicial('Comida', const [
      ('Apple', 'Manzana'),
      ('Bread', 'Pan'),
      ('Water', 'Agua'),
    ], correctAnswers: 4);
    await _crearTemaInicial('Colores', const [
      ('Green', 'Verde'),
      ('Blue', 'Azul'),
      ('Red', 'Rojo'),
    ], correctAnswers: 3);
  }

  Future<void> _crearTemaInicial(
    String nombre,
    List<(String, String)> traducciones, {
    required int correctAnswers,
  }) async {
    final temaId = await _temaRepository.crear(Tema(nombre: nombre));
    final palabras = <Palabra>[];
    for (final (ingles, espanol) in traducciones) {
      final palabraId = await _palabraRepository.crear(
        Palabra(temaId: temaId, ingles: ingles, espanol: espanol),
      );
      palabras.add(
        Palabra(
          id: palabraId,
          temaId: temaId,
          ingles: ingles,
          espanol: espanol,
        ),
      );
    }

    for (var index = 0; index < 5; index++) {
      await _intentoRepository.crear(
        Intento(
          palabraId: palabras[index % palabras.length].id!,
          fecha: DateTime(2026, 10, 28).subtract(Duration(days: index)),
          acierto: index < correctAnswers,
        ),
      );
    }
  }
}
