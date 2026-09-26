import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_acelerometro/core/sensors/accelerometer_service.dart';
import 'package:juegos_acelerometro/games/tilt_maze/tilt_maze_game.dart';
import 'package:juegos_acelerometro/games/tilt_maze/tilt_maze_level.dart';
import 'package:juegos_acelerometro/games/tilt_maze/tilt_maze_screen.dart';

class _FakeAccelerometerService extends AccelerometerService {
  final _controller = StreamController<AccelerometerReading>.broadcast(
    sync: true,
  );

  @override
  Stream<AccelerometerReading> get readings => _controller.stream;

  @override
  void start() {}

  void emit(double x, double y) {
    _controller.add(
      AccelerometerReading(
        x: x,
        y: y,
        z: 0,
        magnitude: math.sqrt(x * x + y * y),
      ),
    );
  }

  @override
  Future<void> dispose() => _controller.close();
}

void main() {
  test('Three levels have distinct tracks and obstacles', () {
    expect(tiltMazeLevels.map((level) => level.id), [1, 2, 3]);
    expect(tiltMazeLevels.map((level) => level.path.length).toSet().length, 3);
    expect(
      tiltMazeLevels.map((level) => level.trackWidthFactor).toSet().length,
      3,
    );
    expect(tiltMazeLevels.map((level) => level.lasers.length), [0, 1, 2]);
    expect(tiltMazeLevels.map((level) => level.iceZones.length), [0, 1, 2]);
    for (final level in tiltMazeLevels) {
      expect(level.path.length, greaterThan(1));
      expect(
        level.checkpointIndexes,
        orderedEquals([...level.checkpointIndexes]..sort()),
      );
      expect(level.checkpointIndexes.last, lessThan(level.path.length - 1));
      for (final laser in level.lasers) {
        for (final checkpointIndex in level.checkpointIndexes) {
          final checkpoint = level.path[checkpointIndex];
          expect(
            (laser.x - checkpoint.x).abs() + (laser.y - checkpoint.y).abs(),
            greaterThan(0.1),
          );
        }
      }
    }
  });

  testWidgets('Checkpoints, respawn and portal use valid progress', (
    tester,
  ) async {
    final sensor = _FakeAccelerometerService();
    final game = TiltMazeGame(
      level: tiltMazeLevel1,
      accelerometerService: sensor,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 400, height: 500, child: GameWidget(game: game)),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.hud.value.totalCheckpoints, 2);

    final ball = game.children.whereType<GlowingBallComponent>().single;
    Vector2 pointAt(int index) {
      final point = tiltMazeLevel1.path[index];
      final usableHeight = math.max(200.0, game.size.y - 215);
      return Vector2(game.size.x * point.x, 160 + usableHeight * point.y);
    }

    ball.position = pointAt(5);
    game.update(0);
    expect(game.hud.value.checkpoint, 0);

    ball.position = pointAt(tiltMazeLevel1.path.length - 1);
    game.update(0);
    expect(game.hud.value.completed, isFalse);

    ball.position = pointAt(3);
    game.update(0);
    expect(game.hud.value.checkpoint, 1);

    ball.position = Vector2(-100, -100);
    game.update(0);
    for (var i = 0; i < 14; i++) {
      game.update(0.05);
    }
    expect(ball.position.x, closeTo(pointAt(3).x, 0.001));
    expect(ball.position.y, closeTo(pointAt(3).y, 0.001));

    ball.position = pointAt(5);
    game.update(0);
    expect(game.hud.value.checkpoint, 2);
    ball.position = pointAt(tiltMazeLevel1.path.length - 1);
    game.update(0);
    expect(game.hud.value.completed, isTrue);

    game.restartLevel();
    expect(game.hud.value.checkpoint, 0);
    expect(game.hud.value.completed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Calibration keeps axis directions and sensitivity scales input',
    (tester) async {
      final sensor = _FakeAccelerometerService();
      final game = TiltMazeGame(
        level: tiltMazeLevel1,
        accelerometerService: sensor,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 500,
            child: GameWidget(game: game),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final ball = game.children.whereType<GlowingBallComponent>().single;
      sensor.emit(0, 0);
      final start = ball.position.clone();
      sensor.emit(1, 0);
      game.update(0.05);
      expect(ball.position.x, lessThan(start.x));

      game.restartLevel();
      expect(game.calibrate(), isTrue);
      final neutral = ball.position.clone();
      sensor.emit(1, 0);
      game.update(0.05);
      expect(ball.position.x, closeTo(neutral.x, 0.001));

      sensor.emit(1, 1);
      game.update(0.05);
      expect(ball.position.y, greaterThan(neutral.y));

      game.setTouchMode(true);
      game.restartLevel();
      sensor.emit(9, 9);
      game.update(0.05);
      expect(ball.position.x, closeTo(neutral.x, 0.001));
      expect(ball.position.y, closeTo(neutral.y, 0.001));

      game.touchInput = Vector2(1, 0);
      game.sensitivity = 0.5;
      game.update(0.05);
      final lowResponse = ball.position.x - neutral.x;
      game.restartLevel();
      game.touchInput = Vector2(1, 0);
      game.sensitivity = 1.5;
      game.update(0.05);
      final highResponse = ball.position.x - neutral.x;
      expect(highResponse, greaterThan(lowResponse * 2));

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Background pause freezes play until resumed explicitly', (
    tester,
  ) async {
    final sensor = _FakeAccelerometerService();
    await tester.pumpWidget(
      MaterialApp(
        home: TiltMazeScreen(
          level: tiltMazeLevel2,
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
    final game = widget.game as TiltMazeGame;
    sensor.emit(0, 0);
    final reading = game.currentReading.value;
    final ball = game.children.whereType<GlowingBallComponent>().single;
    final laser = game.children.whereType<MovingLaserComponent>().single;
    double beamPosition() {
      for (double x = laser.position.x - 100; x < laser.position.x + 100; x++) {
        if (laser.collidesWithBall(Vector2(x, laser.position.y), 0)) {
          return x;
        }
      }
      throw StateError('Laser beam not found');
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(game.paused, isTrue);
    expect(find.text('PAUSA'), findsOneWidget);
    final elapsed = game.hud.value.time;
    final position = ball.position.clone();
    final beam = beamPosition();
    sensor.emit(8, 8);
    await tester.pump(const Duration(seconds: 2));
    expect(game.hud.value.time, elapsed);
    expect(ball.position, position);
    expect(beamPosition(), beam);
    expect(game.currentReading.value, same(reading));

    ball.position = Vector2(beam, laser.position.y);
    await tester.pump(const Duration(seconds: 1));
    expect(game.hud.value.falling, isFalse);
    ball.position = position;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(game.paused, isTrue);
    await tester.tap(find.text('CONTINUAR'));
    await tester.pump();
    expect(game.paused, isFalse);
    expect(ball.position, position);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(sensor._controller.hasListener, isFalse);
    expect(game.children, isEmpty);
  });

  testWidgets('Final level shows the Tilt Maze completion and can restart', (
    tester,
  ) async {
    final sensor = _FakeAccelerometerService();
    await tester.pumpWidget(
      MaterialApp(
        home: TiltMazeScreen(
          level: tiltMazeLevel3,
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
    final game = widget.game as TiltMazeGame;
    final ball = game.children.whereType<GlowingBallComponent>().single;
    expect(game.children.whereType<MovingLaserComponent>().length, 2);
    expect(game.children.whereType<IceZoneComponent>().length, 2);

    // This test exercises progression independently of the moving hazards.
    for (final laser in game.children.whereType<MovingLaserComponent>()) {
      laser.position = Vector2(-1000, -1000);
    }

    Vector2 pointAt(int index) {
      final point = tiltMazeLevel3.path[index];
      final usableHeight = math.max(200.0, game.size.y - 215);
      return Vector2(game.size.x * point.x, 160 + usableHeight * point.y);
    }

    for (final index in tiltMazeLevel3.checkpointIndexes) {
      ball.position = pointAt(index);
      game.update(0);
    }
    ball.position = pointAt(tiltMazeLevel3.path.length - 1);
    game.update(0);
    await tester.pump();
    expect(find.text('¡COMPLETASTE TILT MAZE!'), findsOneWidget);
    expect(find.text('JUGAR DE NUEVO'), findsOneWidget);
    expect(find.text('SIGUIENTE NIVEL'), findsNothing);

    await tester.tap(find.text('JUGAR DE NUEVO'));
    await tester.pump();
    expect(game.hud.value.completed, isFalse);
    expect(game.hud.value.checkpoint, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Completed level can advance to the next level', (tester) async {
    final sensor = _FakeAccelerometerService();
    await tester.pumpWidget(
      MaterialApp(
        home: TiltMazeScreen(
          level: tiltMazeLevel1,
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
    final game = widget.game as TiltMazeGame;
    final ball = game.children.whereType<GlowingBallComponent>().single;
    Vector2 pointAt(int index) {
      final point = tiltMazeLevel1.path[index];
      final usableHeight = math.max(200.0, game.size.y - 215);
      return Vector2(game.size.x * point.x, 160 + usableHeight * point.y);
    }

    for (final index in tiltMazeLevel1.checkpointIndexes) {
      ball.position = pointAt(index);
      game.update(0);
    }
    ball.position = pointAt(tiltMazeLevel1.path.length - 1);
    game.update(0);
    await tester.pump();
    expect(find.text('SIGUIENTE NIVEL'), findsOneWidget);
    await tester.tap(find.text('SIGUIENTE NIVEL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NIVEL 02'), findsOneWidget);
    expect(sensor._controller.hasListener, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
