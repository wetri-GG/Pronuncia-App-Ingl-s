import 'package:flutter_test/flutter_test.dart';
import 'package:pronuncia/utils/pronunciation_assessment.dart';

void main() {
  test('la coincidencia exacta ignora mayúsculas y puntuación', () {
    expect(pronunciationMatchScore('Hello', 'HELLO!'), 100);
  });

  test('la puntuación baja con errores de transcripción', () {
    expect(pronunciationMatchScore('apple', 'appl'), 80);
    expect(pronunciationMatchScore('apple', 'xyz'), lessThan(80));
  });

  test('una transcripción vacía no obtiene puntuación', () {
    expect(pronunciationMatchScore('Hello', ''), 0);
  });
}
