import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronuncia/main.dart';
import 'package:pronuncia/widgets/flip_card.dart';

void main() {
  testWidgets('se puede abrir, girar y responder tarjetas', (tester) async {
    await tester.pumpWidget(const MainApp());

    await tester.tap(find.text('Animales'));
    await tester.pumpAndSettle();
    expect(find.text('Dog'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);

    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();
    expect(find.text('Perro'), findsOneWidget);

    await tester.tap(find.text('Lo sé'));
    await tester.pumpAndSettle();
    expect(find.text('Cat'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);

    await tester.tap(find.text('No lo sé'));
    await tester.pumpAndSettle();
    expect(find.text('Bird'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget);
  });

  testWidgets('se puede añadir un tema desde la lista', (tester) async {
    await tester.pumpWidget(const MainApp());

    await tester.tap(find.text('Añadir tema'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Viajes');
    await tester.tap(find.text('Añadir').last);
    await tester.pumpAndSettle();

    expect(find.text('Viajes'), findsOneWidget);
    expect(find.text('0 palabras'), findsOneWidget);
  });
}
