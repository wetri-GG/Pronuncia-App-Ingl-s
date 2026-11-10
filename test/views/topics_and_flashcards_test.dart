import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> openTopics(WidgetTester tester) async {
    await tester.tap(find.text('Temas y tarjetas'));
    await tester.pumpAndSettle();
  }

  Future<void> openAnimalsFlashcards(WidgetTester tester) async {
    await openTopics(tester);
    await tester.tap(find.text('Animales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practicar tarjetas'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollHomeTo(WidgetTester tester, String label) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      if (find.text(label).evaluate().isNotEmpty) {
        await tester.ensureVisible(find.text(label).first);
        return;
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
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
    expect(controller.temas, hasLength(5));
    expect(controller.palabrasDe(controller.temas.first), hasLength(4));
    final numbers = controller.temas.singleWhere(
      (tema) => tema.nombre == 'Números',
    );
    expect(controller.palabrasDe(numbers), hasLength(11));
    expect(
      controller.palabrasDe(numbers).map((word) => word.ingles),
      containsAll(['Zero', 'Five', 'Ten']),
    );
  });

  testWidgets('se puede abrir, girar y responder tarjetas', (tester) async {
    await pumpApp(tester);

    await openAnimalsFlashcards(tester);
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

    await openTopics(tester);
    await tester.tap(find.text('Añadir tema'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Viajes');
    await tester.tap(find.text('Añadir').last);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await pumpDatabase(tester);

    final temaGuardado = await tester.runAsync(
      () async => (await temaRepository.obtenerTodos()).any(
        (tema) => tema.nombre == 'Viajes',
      ),
    );
    expect(temaGuardado, isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Viajes'), findsOneWidget);
    expect(find.text('0 palabras'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester);
    await openTopics(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Viajes'), findsOneWidget);
  });

  testWidgets('se puede añadir y persistir una palabra en un tema', (
    tester,
  ) async {
    await pumpApp(tester);
    await openTopics(tester);
    await tester.tap(find.text('Animales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir palabra'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Palabra en inglés'),
      'Horse',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Traducción al español'),
      'Caballo',
    );
    await tester.tap(find.text('Guardar palabra'));
    await pumpDatabase(tester);

    expect(find.text('Horse'), findsOneWidget);
    expect(find.text('Caballo'), findsOneWidget);
    final wordSaved = await tester.runAsync(
      () async => (await palabraRepository.obtenerPorTema(
        (await temaRepository.obtenerTodos())
            .singleWhere((tema) => tema.nombre == 'Animales')
            .id!,
      )).any((palabra) => palabra.ingles == 'Horse'),
    );
    expect(wordSaved, isTrue);
  });

  testWidgets('el menú abre la pantalla de estadísticas', (tester) async {
    await pumpApp(tester);
    await scrollHomeTo(tester, 'Estadísticas');
    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();

    expect(find.text('Estadísticas'), findsOneWidget);
    expect(find.text('Aciertos totales'), findsOneWidget);
    expect(find.text('Aciertos por tema'), findsOneWidget);
  });

  testWidgets('la práctica oral permite filtrar por tema', (tester) async {
    await pumpApp(tester);
    await scrollHomeTo(tester, 'Práctica oral');
    await tester.tap(find.text('Práctica oral'));
    await tester.pumpAndSettle();

    expect(find.text('Perro'), findsOneWidget);
    expect(find.text('Manzana'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comida').last);
    await tester.pumpAndSettle();

    expect(find.text('Manzana'), findsOneWidget);
    expect(find.text('Perro'), findsNothing);
  });

  testWidgets('el menu abre las pantallas de voz y conversacion', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugin.csdcorp.com/speech_to_text'),
      (_) async => null,
    );
    await pumpApp(tester);

    await scrollHomeTo(tester, 'Texto a voz');
    await tester.tap(find.text('Texto a voz'));
    await tester.pumpAndSettle();
    expect(find.text('Escucha cómo suena tu texto'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await scrollHomeTo(tester, 'Conversación bilingüe');
    await tester.tap(find.text('Conversación bilingüe'));
    await tester.pumpAndSettle();
    expect(find.text('Conversación bilingüe'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
