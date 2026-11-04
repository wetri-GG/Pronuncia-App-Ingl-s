import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pronuncia/controllers/demo_study_controller.dart';
import 'package:pronuncia/data/database_helper.dart';
import 'package:pronuncia/data/intento_repository.dart';
import 'package:pronuncia/data/palabra_repository.dart';
import 'package:pronuncia/data/tema_repository.dart';
import 'package:pronuncia/main.dart';
import 'package:pronuncia/widgets/flip_card.dart';

void main() {
  late Directory directorioTemporal;
  late DatabaseHelper databaseHelper;
  late TemaRepository temaRepository;
  late PalabraRepository palabraRepository;
  late IntentoRepository intentoRepository;

  setUp(() async {
    directorioTemporal = await Directory.systemTemp.createTemp(
      'pronuncia-ui-test-',
    );
    databaseHelper = DatabaseHelper(
      databasePath: join(directorioTemporal.path, 'test.db'),
    );
    temaRepository = TemaRepository(databaseHelper);
    palabraRepository = PalabraRepository(databaseHelper);
    intentoRepository = IntentoRepository(databaseHelper);
  });

  tearDown(() async {
    await databaseHelper.close();
    await directorioTemporal.delete(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final controller = DemoStudyController(databaseHelper: databaseHelper);
    await tester.runAsync(controller.cargar);
    await tester.pumpWidget(MainApp(studyController: controller));
    await tester.pumpAndSettle();
  }

  Future<void> pumpDatabase(WidgetTester tester) async {
    await tester.runAsync(() async {
      await temaRepository.obtenerTodos();
      await palabraRepository.obtenerTodos();
      await intentoRepository.obtenerTodos();
    });
    for (var index = 0; index < 5; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  test('el controlador carga y conserva los datos de estudio', () async {
    final controller = DemoStudyController(databaseHelper: databaseHelper);
    await controller.cargar().timeout(const Duration(seconds: 10));

    expect(controller.error, isNull);
    expect(controller.temas, hasLength(3));
    expect(controller.palabrasDe(controller.temas.first), hasLength(4));
  });

  testWidgets('se puede abrir, girar y responder tarjetas', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Animales'));
    await tester.pumpAndSettle();
    expect(find.text('Dog'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);

    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();
    expect(find.text('Perro'), findsOneWidget);

    await tester.tap(find.text('Lo sé'));
    await pumpDatabase(tester);
    expect(find.text('Cat'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);

    final storedResponse = await tester.runAsync(() async {
      final tema = (await temaRepository.obtenerTodos()).singleWhere(
        (tema) => tema.nombre == 'Animales',
      );
      final palabra = (await palabraRepository.obtenerPorTema(tema.id!)).first;
      final intentos = await intentoRepository.obtenerPorPalabra(palabra.id!);
      return (tema.nombre, palabra.ingles, intentos.length);
    });
    expect(storedResponse, isNotNull);
    final (temaNombre, palabraIngles, cantidadIntentos) = storedResponse!;
    expect(temaNombre, 'Animales');
    expect(palabraIngles, 'Dog');
    expect(cantidadIntentos, 3);

    await tester.tap(find.text('No lo sé'));
    await pumpDatabase(tester);
    expect(find.text('Bird'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget);
  });

  testWidgets('se puede añadir un tema desde la lista', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Añadir tema'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Viajes');
    await tester.tap(find.text('Añadir').last);
    await pumpDatabase(tester);

    expect(find.text('Viajes'), findsOneWidget);
    expect(find.text('0 palabras'), findsOneWidget);
    final temaGuardado = await tester.runAsync(
      () async => (await temaRepository.obtenerTodos()).any(
        (tema) => tema.nombre == 'Viajes',
      ),
    );
    expect(temaGuardado, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester);
    expect(find.text('Viajes'), findsOneWidget);
  });
}
