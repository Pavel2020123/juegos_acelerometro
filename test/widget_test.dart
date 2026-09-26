import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_acelerometro/main.dart';

void main() {
  testWidgets('Shows the three maze levels', (tester) async {
    await tester.pumpWidget(const AccelLabApp());

    expect(find.text('TILT MAZE'), findsOneWidget);
    expect(find.text('Primer contacto'), findsOneWidget);
    expect(find.text('Zona congelada'), findsOneWidget);
    expect(find.text('Órbita extrema'), findsOneWidget);
  });
}
