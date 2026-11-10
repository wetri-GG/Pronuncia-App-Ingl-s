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
  Map<int, ({int intentos, int aciertos})> _estadisticasPorTema = {};
  List<({Palabra palabra, int fallos})> _palabrasMasFalladas = [];
  bool isLoading = false;
  Object? error;

  List<Tema> get temas => List.unmodifiable(_temas);

  List<Palabra> get todasLasPalabras => List.unmodifiable(
    _temas.expand((tema) => _palabrasPorTema[tema.id] ?? const <Palabra>[]),
  );

  List<Intento> get todosLosIntentos =>
      List.unmodifiable(_intentosPorTema.values.expand((intentos) => intentos));

  List<Palabra> palabrasDe(Tema tema) =>
      List.unmodifiable(_palabrasPorTema[tema.id] ?? const []);

  Tema? temaPorId(int id) {
    for (final tema in _temas) {
      if (tema.id == id) return tema;
    }
    return null;
  }

  Palabra? palabraPorIngles(String ingles) {
    for (final palabra in todasLasPalabras) {
      if (palabra.ingles.toLowerCase() == ingles.toLowerCase()) {
        return palabra;
      }
    }
    return null;
  }

  List<({Palabra palabra, int fallos})> get palabrasMasFalladas =>
      List.unmodifiable(_palabrasMasFalladas);

  int get totalAciertos =>
      todosLosIntentos.where((intento) => intento.acierto).length;

  int get totalIntentos => todosLosIntentos.length;

  int get porcentajeGlobal =>
      totalIntentos == 0 ? 0 : (totalAciertos * 100 / totalIntentos).round();

  int porcentajeAcierto(Tema tema) {
    final estadistica = _estadisticasPorTema[tema.id];
    if (estadistica == null || estadistica.intentos == 0) return 0;
    return (estadistica.aciertos * 100 / estadistica.intentos).round();
  }

  Future<void> cargar() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final temas = await _temaRepository.obtenerTodos();
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
      await _cargarAgregados();
    } catch (exception) {
      error = exception;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Palabra> obtenerOCrearPalabraActividad({
    required String temaNombre,
    required String ingles,
    required String espanol,
  }) async {
    final temaKey = temaNombre.trim().toLowerCase();
    final english = ingles.trim();
    final spanish = espanol.trim();
    if (temaKey.isEmpty || english.isEmpty || spanish.isEmpty) {
      throw ArgumentError('El tema y las dos traducciones son obligatorios.');
    }

    var tema = _temas.cast<Tema?>().firstWhere(
      (item) => item?.nombre.toLowerCase() == temaKey,
      orElse: () => null,
    );
    if (tema == null) {
      final id = await _temaRepository.crear(Tema(nombre: temaNombre.trim()));
      tema = Tema(id: id, nombre: temaNombre.trim());
      _temas = [..._temas, tema];
      _palabrasPorTema[id] = [];
      _intentosPorTema[id] = [];
      _estadisticasPorTema[id] = (intentos: 0, aciertos: 0);
    }

    final existentes = _palabrasPorTema[tema.id] ?? const <Palabra>[];
    for (final palabra in existentes) {
      if (palabra.ingles.toLowerCase() == english.toLowerCase()) {
        return palabra;
      }
    }

    final id = await _palabraRepository.crear(
      Palabra(temaId: tema.id!, ingles: english, espanol: spanish),
    );
    final palabra = Palabra(
      id: id,
      temaId: tema.id!,
      ingles: english,
      espanol: spanish,
    );
    _palabrasPorTema[tema.id]!.add(palabra);
    notifyListeners();
    return palabra;
  }

  Future<void> agregarTema(String nombre) async {
    final id = await _temaRepository.crear(Tema(nombre: nombre.trim()));
    final tema = Tema(id: id, nombre: nombre.trim());
    _temas = [..._temas, tema];
    _palabrasPorTema[id] = [];
    _intentosPorTema[id] = [];
    _estadisticasPorTema[id] = (intentos: 0, aciertos: 0);
    notifyListeners();
  }

  Future<void> agregarPalabra({
    required int temaId,
    required String ingles,
    required String espanol,
  }) async {
    final tema = temaPorId(temaId);
    if (tema == null) {
      throw ArgumentError('No existe el tema seleccionado.');
    }

    final limpiaIngles = ingles.trim();
    final limpiaEspanol = espanol.trim();
    if (limpiaIngles.isEmpty || limpiaEspanol.isEmpty) {
      throw ArgumentError('La palabra y su traducción son obligatorias.');
    }

    final id = await _palabraRepository.crear(
      Palabra(temaId: temaId, ingles: limpiaIngles, espanol: limpiaEspanol),
    );
    _palabrasPorTema[temaId]!.add(
      Palabra(
        id: id,
        temaId: temaId,
        ingles: limpiaIngles,
        espanol: limpiaEspanol,
      ),
    );
    notifyListeners();
  }

  Future<void> registrarRespuesta(
    Palabra palabra, {
    required bool conocida,
    String origen = 'tarjetas',
    String? textoReconocido,
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
      textoReconocido: textoReconocido,
      origen: origen,
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
        textoReconocido: intento.textoReconocido,
        origen: intento.origen,
      ),
    );
    await _cargarAgregados();
    notifyListeners();
  }

  Future<void> _cargarAgregados() async {
    final estadisticas = await _intentoRepository.obtenerEstadisticasPorTema();
    final palabrasFalladas = await _intentoRepository
        .obtenerPalabrasMasFalladas();
    _estadisticasPorTema = {
      for (final estadistica in estadisticas)
        estadistica.temaId: (
          intentos: estadistica.intentos,
          aciertos: estadistica.aciertos,
        ),
    };
    _palabrasMasFalladas = palabrasFalladas;
  }
}
