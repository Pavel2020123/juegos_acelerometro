import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_acelerometro/main.dart';

void main() {
  testWidgets('Opens both game selectors', (tester) async {
    await tester.pumpWidget(const AccelLabApp());

    expect(find.text('TILT MAZE'), findsOneWidget);
    expect(find.text('BALANCE MASTER'), findsOneWidget);

    await tester.tap(find.text('BALANCE MASTER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Equilibrio básico'), findsOneWidget);
    expect(find.text('Doble equilibrio'), findsOneWidget);
    expect(find.text('Caos controlado'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver a juegos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('TILT MAZE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Primer contacto'), findsOneWidget);
  });
}
