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
    expect(
      balanceMasterLevels.map((level) => level.objectives.length),
      orderedEquals([1, 3, 3]),
    );
    for (final level in balanceMasterLevels) {
      for (final objective in level.objectives) {
        expect(objective.objectIndex, lessThan(level.objectCount));
        expect(
          objective.appearAt + objective.availableSeconds,
          lessThanOrEqualTo(level.duration),
        );
        expect(
          objective.centerFactor.abs() + objective.widthFactor / 2,
          lessThan(0.5 - level.hazardInset / (400 * level.platformWidthFactor)),
        );
      }
    }
  });

  test('Stars reward stability and objectives without harsh thresholds', () {
    expect(
      balanceStars(
        averageStability: 60,
        objectivesCompleted: 3,
        totalObjectives: 3,
      ),
      1,
    );
    expect(
      balanceStars(
        averageStability: 78,
        objectivesCompleted: 0,
        totalObjectives: 3,
      ),
      2,
    );
    expect(
      balanceStars(
        averageStability: 88,
        objectivesCompleted: 2,
        totalObjectives: 3,
      ),
      3,
    );
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

  testWidgets('Objective appears, fills with a valid object and scores', (
    tester,
  ) async {
    final sensor = _FakeSensor();
    final game = BalanceMasterGame(
      level: balanceMasterLevels[0],
      accelerometerService: sensor,
    );
    await _load(tester, game);
    game.setTouchMode(true);
    _start(game);
    for (var i = 0; i < 155; i++) {
      game.update(0.05);
    }
    expect(game.activeObjective, isNull);
    for (var i = 0; i < 7; i++) {
      game.update(0.05);
    }
    expect(game.activeObjective, isNotNull);
    expect(game.hud.value.objectiveIndex, 0);
    expect(game.hud.value.objectiveProgress, greaterThan(0));
    final scoreBefore = game.hud.value.score;
    for (var i = 0; i < 45; i++) {
      game.update(0.05);
    }
    expect(game.hud.value.objectivesCompleted, 1);
    expect(game.hud.value.objectiveCompletedPulse, isTrue);
    expect(game.hud.value.score, greaterThan(scoreBefore + 400));
    game.restart();
    expect(game.hud.value.score, 0);
    expect(game.hud.value.objectivesCompleted, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Level two targets one object at a time', (tester) async {
    final sensor = _FakeSensor();
    final game = BalanceMasterGame(
      level: balanceMasterLevels[1],
      accelerometerService: sensor,
    );
    await _load(tester, game);
    game.setTouchMode(true);
    _start(game);
    while (game.hud.value.elapsed < 4.1) {
      game.update(0.05);
    }
    expect(game.hud.value.objectiveIndex, 0);
    final first = game.activeObjective!;
    game.objects[0].x = game.platformWidth * first.centerFactor;
    for (var i = 0; i < 35; i++) {
      game.update(0.05);
    }
    expect(game.hud.value.objectivesCompleted, 1);
    while (game.hud.value.elapsed < 12.1) {
      game.update(0.05);
    }
    expect(game.hud.value.objectiveIndex, 1);
    final second = game.activeObjective!;
    game.objects[1].x = game.platformWidth * second.centerFactor;
    for (var i = 0; i < 40; i++) {
      game.update(0.05);
    }
    expect(game.hud.value.objectivesCompleted, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Stable play builds combo and abrupt motion breaks it', (
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
    for (var i = 0; i < 125; i++) {
      game.update(0.05);
    }
    expect(game.hud.value.combo, greaterThanOrEqualTo(3));
    expect(game.hud.value.maxCombo, greaterThanOrEqualTo(3));
    expect(game.hud.value.score, greaterThan(0));
    sensor.emit(2, 0);
    game.update(0.05);
    expect(game.hud.value.combo, 1);
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

  testWidgets(
    'Gust and platform warn first, then move gently and pause freezes',
    (tester) async {
      final sensor = _FakeSensor();
      final game = BalanceMasterGame(
        level: balanceMasterLevels[2],
        accelerometerService: sensor,
      );
      await _load(tester, game);
      game.setTouchMode(true);
      _start(game);
      while (game.hud.value.elapsed < 8.2) {
        game.update(0.05);
      }
      expect(game.hud.value.impulseWarning, isTrue);
      expect(game.hud.value.gustFromLeft, isTrue);
      final elapsed = game.hud.value.elapsed;
      final points = game.hud.value.score;
      final combo = game.hud.value.combo;
      final progress = game.hud.value.objectiveProgress;
      final shift = game.platformShift;
      game.pausePlay();
      game.update(2);
      expect(game.hud.value.elapsed, elapsed);
      expect(game.hud.value.score, points);
      expect(game.hud.value.combo, combo);
      expect(game.hud.value.objectiveProgress, progress);
      expect(game.platformShift, shift);
      expect(game.hud.value.impulseWarning, isTrue);
      game.resumePlay();

      while (game.hud.value.elapsed < 9.1) {
        game.update(0.05);
      }
      expect(game.hud.value.platformWarning, isTrue);
      expect(game.hud.value.impulseWarning, isFalse);
      while (game.hud.value.elapsed < 10.05) {
        game.update(0.05);
      }
      for (final object in game.objects) {
        object.velocity = 0;
      }
      final beforeMotion = game.objects.map((object) => object.x).toList();
      while (game.hud.value.elapsed < 11.2) {
        game.update(0.05);
      }
      expect(
        (game.objects.first.x - beforeMotion.first).abs(),
        greaterThan(0.1),
      );
      expect(
        game.platformShift.abs(),
        lessThanOrEqualTo(balanceMasterLevels[2].platformShift),
      );
      expect(game.platformShift.abs(), greaterThan(2));
      expect(game.phase, BalancePhase.playing);
      while (game.hud.value.elapsed < 13) {
        game.update(0.05);
      }
      expect(game.platformShift, closeTo(0, 0.01));
      while (game.hud.value.elapsed < 17.2) {
        game.update(0.05);
      }
      expect(game.hud.value.impulseWarning, isTrue);
      expect(game.hud.value.gustFromLeft, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
    expect(find.text('★★★'), findsOneWidget);
    expect(find.text('Objetivos: 1/1'), findsOneWidget);
    expect(find.textContaining('Puntos:'), findsOneWidget);
    expect(find.text('JUGAR DE NUEVO'), findsOneWidget);
    await tester.tap(find.text('SIGUIENTE NIVEL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('NIVEL 02'), findsOneWidget);
    expect(sensor.controller.hasListener, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Objective HUD shows progress and completion feedback', (
    tester,
  ) async {
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
    while (game.hud.value.elapsed < 8.2) {
      game.update(0.05);
    }
    await tester.pump();
    expect(find.text('OBJETIVO · MANTÉN LA ESFERA EN LA ZONA'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    for (var i = 0; i < 100 && game.hud.value.objectivesCompleted == 0; i++) {
      game.update(0.05);
    }
    expect(game.hud.value.objectivesCompleted, 1);
    await tester.pump();
    expect(find.text('✓ OBJETIVO COMPLETADO'), findsOneWidget);
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

  testWidgets('Level three shows directional gust and platform warnings', (
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
    while (game.hud.value.elapsed < 8.2) {
      game.update(0.05);
    }
    await tester.pump();
    expect(find.text('⚠ RÁFAGA DESDE LA IZQUIERDA'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
    while (game.hud.value.elapsed < 9.2) {
      game.update(0.05);
    }
    await tester.pump();
    expect(find.text('⚠ PLATAFORMA INESTABLE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
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
