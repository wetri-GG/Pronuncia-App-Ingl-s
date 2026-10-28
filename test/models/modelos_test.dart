import 'package:flutter_test/flutter_test.dart';
import 'package:pronuncia/models/tema.dart';
import 'package:pronuncia/models/palabra.dart';
import 'package:pronuncia/models/intento.dart';

void main() {
  test('Tema se convierte a mapa y vuelve', () {
    const tema = Tema(id: 1, nombre: 'Animales');

    final map = tema.toMap();
    expect(map, {'id': 1, 'nombre': 'Animales'});

    final recuperado = Tema.fromMap(map);
    expect(recuperado.id, 1);
    expect(recuperado.nombre, 'Animales');
  });

  test('Palabra se convierte a mapa y vuelve', () {
    const palabra = Palabra(
      id: 2,
      temaId: 1,
      ingles: 'cat',
      espanol: 'gato',
    );

    final map = palabra.toMap();
    expect(map['tema_id'], 1);
    expect(map['ingles'], 'cat');
    expect(map['espanol'], 'gato');

    final recuperada = Palabra.fromMap(map);
    expect(recuperada.id, 2);
    expect(recuperada.temaId, 1);
    expect(recuperada.ingles, 'cat');
    expect(recuperada.espanol, 'gato');
  });

  test('Intento convierte fecha y acierto correctamente', () {
    final fecha = DateTime.utc(2026, 10, 28, 17);
    final intento = Intento(
      id: 3,
      palabraId: 2,
      fecha: fecha,
      acierto: true,
      textoReconocido: 'cat',
    );

    final map = intento.toMap();
    expect(map['palabra_id'], 2);
    expect(map['fecha'], fecha.toIso8601String());
    expect(map['acierto'], 1);
    expect(map['texto_reconocido'], 'cat');

    final recuperado = Intento.fromMap(map);
    expect(recuperado.id, 3);
    expect(recuperado.palabraId, 2);
    expect(recuperado.fecha, fecha);
    expect(recuperado.acierto, isTrue);
    expect(recuperado.textoReconocido, 'cat');
  });
}