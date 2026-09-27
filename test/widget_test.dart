import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_acelerometro/games/astro_tilt/astro_tilt_level_select_screen.dart';
import 'package:juegos_acelerometro/games/balance_master/balance_master_level_select_screen.dart';
import 'package:juegos_acelerometro/games/tilt_maze/tilt_maze_level_select_screen.dart';
import 'package:juegos_acelerometro/main.dart';

void main() {
  testWidgets('Opens both game selectors', (tester) async {
    final appLogo = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/images/Logo.png',
    );

    await tester.pumpWidget(const AccelLabApp());

    expect(appLogo, findsOneWidget);
    expect(find.text('ASTROTILT'), findsOneWidget);
    expect(find.text('TILT MAZE'), findsOneWidget);
    expect(find.text('BALANCE MASTER'), findsOneWidget);

    await tester.tap(find.text('BALANCE MASTER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.descendant(
        of: find.byType(BalanceMasterLevelSelectScreen),
        matching: appLogo,
      ),
      findsOneWidget,
    );
    expect(find.text('Equilibrio básico'), findsOneWidget);
    expect(find.text('Doble equilibrio'), findsOneWidget);
    expect(find.text('Caos controlado'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver a juegos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('ASTROTILT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(AstroTiltLevelSelectScreen), findsOneWidget);
    expect(find.text('Patrulla orbital'), findsOneWidget);
    expect(find.text('Campo de asteroides'), findsOneWidget);
    expect(find.text('Batalla final'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AstroTiltLevelSelectScreen),
        matching: appLogo,
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Volver a juegos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('TILT MAZE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.descendant(
        of: find.byType(TiltMazeLevelSelectScreen),
        matching: appLogo,
      ),
      findsOneWidget,
    );
    expect(find.text('Primer contacto'), findsOneWidget);
  });
}
