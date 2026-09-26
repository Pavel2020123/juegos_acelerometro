import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_acelerometro/core/sensors/accelerometer_service.dart';
import 'package:juegos_acelerometro/games/balance_master/balance_master_game.dart';
import 'package:juegos_acelerometro/games/balance_master/balance_master_level.dart';
import 'package:juegos_acelerometro/games/balance_master/balance_master_screen.dart';

class _FakeSensor extends AccelerometerService {
  final controller = StreamController<AccelerometerReading>.broadcast(
    sync: true,
  );

  @override
  Stream<AccelerometerReading> get readings => controller.stream;

  @override
  void start() {}

  void emit(double x, double y) =>
      controller.add(AccelerometerReading(x: x, y: y, z: 0, magnitude: 0));

  void fail() => controller.addError(StateError('Sensor unavailable'));

  @override
  Future<void> dispose() => controller.close();
}

Future<void> _load(WidgetTester tester, BalanceMasterGame game) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(width: 400, height: 500, child: GameWidget(game: game)),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void _start(BalanceMasterGame game) {
  expect(game.calibrate(), isTrue);
  expect(game.phase, BalancePhase.countdown);
  for (var i = 0; i < 74; i++) {
    game.update(0.05);
  }
  expect(game.phase, BalancePhase.playing);
}

void main() {
  test('Levels configure three different balance challenges', () {
    expect(balanceMasterLevels.map((level) => level.objectCount), [1, 2, 3]);
    expect(balanceMasterLevels.map((level) => level.duration), [20, 25, 30]);
    expect(
      balanceMasterLevels.map((level) => level.platformWidthFactor),
      orderedEquals([0.82, 0.75, 0.72]),
    );
    expect(balanceMasterLevels[2].perturbationInterval, greaterThan(0));
  });

  testWidgets('Calibration freezes countdown and stability reacts smoothly', (
    tester,
  ) async {
    final sensor = _FakeSensor();
    final game = BalanceMasterGame(
      level: balanceMasterLevels[0],
      accelerometerService: sensor,
    );
    await _load(tester, game);
    expect(game.objects.length, 1);
    expect(game.calibrate(), isFalse);
    sensor.emit(2, -1);
    final startX = game.objects.single.x;
    expect(game.calibrate(), isTrue);
    expect(game.neutralX, 2);
    expect(game.neutralY, -1);
    sensor.emit(5, -1);
    for (var i = 0; i < 20; i++) {
      game.update(0.05);
    }
    expect(game.objects.single.x, startX);
    for (var i = 0; i < 54; i++) {
      game.update(0.05);
    }
    expect(game.phase, BalancePhase.playing);
    sensor.emit(2, -1);
    game.update(0.05);
    expect(game.objects.single.x, closeTo(startX, 0.01));
    sensor.emit(3.5, 0);
    for (var i = 0; i < 6; i++) {
      game.update(0.05);
    }
    expect(game.hud.value.stability, lessThan(100));
    expect(game.hud.value.stability, greaterThan(20));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(sensor.controller.hasListener, isFalse);
  });

  testWidgets('Touch input is separate and can cause a fair fall', (
    tester,
  ) async {
    final sensor = _FakeSensor();
    final game = BalanceMasterGame(
      level: balanceMasterLevels[1],
      accelerometerService: sensor,
    );
    await _load(tester, game);
    expect(game.objects.length, 2);
    game.setTouchMode(true);
    _start(game);
    final start = game.objects.first.x;
    sensor.emit(20, 20);
    game.update(0.05);
    expect(game.objects.first.x, start);
    game.setTouchTilt(0.55);
    for (var i = 0; i < 10; i++) {
      game.update(0.05);
    }
    expect(game.objects.first.x, greaterThan(start));
    game.setTouchTilt(1);
    for (var i = 0; i < 400 && game.phase == BalancePhase.playing; i++) {
      game.update(0.05);
    }
    expect(game.phase, BalancePhase.falling);
    for (var i = 0; i < 14; i++) {
      game.update(0.05);
    }
    expect(game.phase, BalancePhase.lost);
    game.restart();
    expect(game.phase, BalancePhase.calibrating);
    expect(game.objects.length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Pause freezes time and objects, then stable play wins', (
    tester,
  ) async {
    final sensor = _FakeSensor();
    final game = BalanceMasterGame(
      level: balanceMasterLevels[2],
      accelerometerService: sensor,
    );
    await _load(tester, game);
    expect(game.objects.length, 3);
    sensor.emit(0, 0);
    _start(game);
    game.update(0.05);
    final time = game.hud.value.elapsed;
    final positions = game.objects.map((object) => object.x).toList();
    game.pausePlay();
    sensor.emit(9, 9);
    game.update(2);
    expect(game.hud.value.elapsed, time);
    expect(game.objects.map((object) => object.x), orderedEquals(positions));
    game.resumePlay();
    var sawImpulseWarning = false;
    for (var i = 0; i < 620 && game.phase == BalancePhase.playing; i++) {
      game.update(0.05);
      sawImpulseWarning |= game.hud.value.impulseWarning;
    }
    expect(game.phase, BalancePhase.won);
    expect(sawImpulseWarning, isTrue);
    expect(game.hud.value.elapsed, 30);
    expect(game.hud.value.averageStability, inInclusiveRange(0, 100));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Sensor loss freezes play until touch fallback is selected', (
    tester,
  ) async {
    final sensor = _FakeSensor();
    final game = BalanceMasterGame(
      level: balanceMasterLevels[0],
      accelerometerService: sensor,
    );
    await _load(tester, game);
    sensor.emit(0, 0);
    _start(game);
    game.update(0.05);
    final time = game.hud.value.elapsed;
    sensor.fail();
    for (var i = 0; i < 50; i++) {
      game.update(0.05);
    }
    expect(game.hud.value.elapsed, time);
    game.setTouchMode(true);
    game.update(0.05);
    expect(game.hud.value.elapsed, greaterThan(time));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Victory screen advances to level two', (tester) async {
    final sensor = _FakeSensor();
    await tester.pumpWidget(
      MaterialApp(
        home: BalanceMasterScreen(
          level: balanceMasterLevels[0],
          accelerometerService: sensor,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final widget = tester.widget<GameWidget>(
      find.byWidgetPredicate((candidate) => candidate is GameWidget),
    );
    final game = widget.game as BalanceMasterGame;
    sensor.emit(0, 0);
    _start(game);
    for (var i = 0; i < 410 && game.phase == BalancePhase.playing; i++) {
      game.update(0.05);
    }
    await tester.pump();
    expect(find.text('¡EQUILIBRIO PERFECTO!'), findsOneWidget);
    expect(find.text('JUGAR DE NUEVO'), findsOneWidget);
    await tester.tap(find.text('SIGUIENTE NIVEL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('NIVEL 02'), findsOneWidget);
    expect(sensor.controller.hasListener, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Backgrounding pauses the screen without accumulating input', (
    tester,
  ) async {
    final sensor = _FakeSensor();
    await tester.pumpWidget(
      MaterialApp(
        home: BalanceMasterScreen(
          level: balanceMasterLevels[2],
          accelerometerService: sensor,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final widget = tester.widget<GameWidget>(
      find.byWidgetPredicate((candidate) => candidate is GameWidget),
    );
    final game = widget.game as BalanceMasterGame;
    sensor.emit(0, 0);
    _start(game);
    game.update(0.05);
    final time = game.hud.value.elapsed;
    final positions = game.objects.map((object) => object.x).toList();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(game.paused, isTrue);
    expect(find.text('PAUSA'), findsOneWidget);
    sensor.emit(9, 9);
    await tester.pump(const Duration(seconds: 2));
    expect(game.hud.value.elapsed, time);
    expect(game.objects.map((object) => object.x), orderedEquals(positions));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(game.paused, isTrue);
    await tester.tap(find.text('CONTINUAR'));
    await tester.pump();
    expect(game.paused, isFalse);
    expect(game.objects.map((object) => object.x), orderedEquals(positions));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(sensor.controller.hasListener, isFalse);
  });

  testWidgets('Level three has its own completion message', (tester) async {
    final sensor = _FakeSensor();
    await tester.pumpWidget(
      MaterialApp(
        home: BalanceMasterScreen(
          level: balanceMasterLevels[2],
          accelerometerService: sensor,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final widget = tester.widget<GameWidget>(
      find.byWidgetPredicate((candidate) => candidate is GameWidget),
    );
    final game = widget.game as BalanceMasterGame;
    sensor.emit(0, 0);
    _start(game);
    for (var i = 0; i < 620 && game.phase == BalancePhase.playing; i++) {
      game.update(0.05);
    }
    await tester.pump();
    expect(find.text('¡BALANCE MASTER COMPLETADO!'), findsOneWidget);
    expect(find.text('SIGUIENTE NIVEL'), findsNothing);
    await tester.tap(find.text('JUGAR DE NUEVO'));
    await tester.pump();
    expect(game.phase, BalancePhase.calibrating);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
