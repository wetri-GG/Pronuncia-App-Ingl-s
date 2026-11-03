import 'package:flutter/foundation.dart';

import '../models/intento.dart';
import '../models/palabra.dart';
import '../models/tema.dart';

class DemoStudyController extends ChangeNotifier {
  DemoStudyController() {
    _addSampleTopic(const Tema(id: 1, nombre: 'Animales'), const [
      Palabra(id: 1, temaId: 1, ingles: 'Dog', espanol: 'Perro'),
      Palabra(id: 2, temaId: 1, ingles: 'Cat', espanol: 'Gato'),
      Palabra(id: 3, temaId: 1, ingles: 'Bird', espanol: 'Pajaro'),
      Palabra(id: 4, temaId: 1, ingles: 'Fish', espanol: 'Pez'),
    ], correctAnswers: 4);
    _addSampleTopic(const Tema(id: 2, nombre: 'Comida'), const [
      Palabra(id: 5, temaId: 2, ingles: 'Apple', espanol: 'Manzana'),
      Palabra(id: 6, temaId: 2, ingles: 'Bread', espanol: 'Pan'),
      Palabra(id: 7, temaId: 2, ingles: 'Water', espanol: 'Agua'),
    ], correctAnswers: 4);
    _addSampleTopic(const Tema(id: 3, nombre: 'Colores'), const [
      Palabra(id: 8, temaId: 3, ingles: 'Green', espanol: 'Verde'),
      Palabra(id: 9, temaId: 3, ingles: 'Blue', espanol: 'Azul'),
      Palabra(id: 10, temaId: 3, ingles: 'Red', espanol: 'Rojo'),
    ], correctAnswers: 3);
  }

  final List<Tema> _temas = [];
  final Map<int, List<Palabra>> _palabrasPorTema = {};
  final Map<int, List<Intento>> _intentosPorTema = {};
  int _nextTopicId = 4;

  List<Tema> get temas => List.unmodifiable(_temas);

  List<Palabra> palabrasDe(Tema tema) =>
      List.unmodifiable(_palabrasPorTema[tema.id] ?? const []);

  int porcentajeAcierto(Tema tema) {
    final intentos = _intentosPorTema[tema.id] ?? const [];
    if (intentos.isEmpty) return 0;

    final aciertos = intentos.where((intento) => intento.acierto).length;
    return (aciertos * 100 / intentos.length).round();
  }

  void agregarTema(String nombre) {
    final id = _nextTopicId++;
    final tema = Tema(id: id, nombre: nombre.trim());
    _temas.add(tema);
    _palabrasPorTema[id] = [];
    _intentosPorTema[id] = [];
    notifyListeners();
  }

  void registrarRespuesta(Palabra palabra, {required bool conocida}) {
    _intentosPorTema[palabra.temaId]!.add(
      Intento(palabraId: palabra.id!, fecha: DateTime.now(), acierto: conocida),
    );
    notifyListeners();
  }

  void _addSampleTopic(
    Tema tema,
    List<Palabra> palabras, {
    required int correctAnswers,
  }) {
    _temas.add(tema);
    _palabrasPorTema[tema.id!] = palabras;
    _intentosPorTema[tema.id!] = List.generate(
      5,
      (index) => Intento(
        palabraId: palabras[index % palabras.length].id!,
        fecha: DateTime(2026, 10, 28).subtract(Duration(days: index)),
        acierto: index < correctAnswers,
      ),
    );
  }
}
