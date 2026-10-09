import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_acelerometro/games/astro_tilt/astro_tilt_level_select_screen.dart';
import 'package:juegos_acelerometro/games/gyro_aim/gyro_aim_screen.dart';
import 'package:juegos_acelerometro/games/tilt_maze/tilt_maze_level_select_screen.dart';
import 'package:juegos_acelerometro/main.dart';
import 'package:juegos_acelerometro/screens/sensor_lab/sensor_lab_screen.dart';

void main() {
  testWidgets('Catalog shows the three active games and Gyro Aim opens', (
    tester,
  ) async {
    await tester.pumpWidget(const AccelLabApp());

    expect(find.text('TILT MAZE'), findsOneWidget);
    expect(find.text('GYRO AIM'), findsOneWidget);
    expect(find.text('ASTROTILT'), findsOneWidget);
    expect(find.text('BALANCE MASTER'), findsNothing);
    expect(find.text('ACELERÓMETRO'), findsNWidgets(2));
    expect(find.text('GIROSCOPIO'), findsOneWidget);

    await tester.tap(find.text('GYRO AIM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(GyroAimScreen), findsOneWidget);
    expect(find.text('Apunta girando tu celular.'), findsOneWidget);
  });

  testWidgets('Existing selectors and the sensor lab remain available', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TiltMazeLevelSelectScreen()),
    );
    expect(find.byType(TiltMazeLevelSelectScreen), findsOneWidget);
    expect(find.text('Primer contacto'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: AstroTiltLevelSelectScreen()),
    );
    expect(find.byType(AstroTiltLevelSelectScreen), findsOneWidget);
    expect(find.text('Patrulla orbital'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SensorLabScreen()));
    await tester.pump();
    expect(find.byType(SensorLabScreen), findsOneWidget);
    expect(find.text('GIROSCOPIO'), findsOneWidget);
    expect(find.text('ACELERÓMETRO'), findsOneWidget);
  });
}
