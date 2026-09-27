import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_acelerometro/core/sensors/accelerometer_service.dart';
import 'package:juegos_acelerometro/games/astro_tilt/astro_tilt_game.dart';
import 'package:juegos_acelerometro/games/astro_tilt/astro_tilt_level.dart';
import 'package:juegos_acelerometro/games/astro_tilt/astro_tilt_screen.dart';

class _FakeAccelerometerService extends AccelerometerService {
  final _controller = StreamController<AccelerometerReading>.broadcast(
    sync: true,
  );
  bool started = false;
  bool disposed = false;

  @override
  Stream<AccelerometerReading> get readings => _controller.stream;

  @override
  void start() {
    started = true;
  }

  void emit(double x, double y) {
    _controller.add(
      AccelerometerReading(
        x: x,
        y: y,
        z: 9.8,
        magnitude: math.sqrt(x * x + y * y + 9.8 * 9.8),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}

AstroTiltGame _readyGame(
  AstroTiltLevel level, {
  _FakeAccelerometerService? sensor,
}) {
  final service = sensor ?? _FakeAccelerometerService();
  final game = AstroTiltGame(level: level, accelerometerService: service);
  game.setViewport(const Size(360, 760));
  service.emit(0, 0);
  game.setTouchMode(true);
  expect(game.calibrate(), isTrue);
  _advance(game, 3.1);
  return game;
}

void _advance(AstroTiltGame game, double seconds) {
  final frames = (seconds / 0.1).ceil();
  for (var frame = 0; frame < frames; frame++) {
    game.update(math.min(0.1, seconds - frame * 0.1).toDouble());
  }
}

void main() {
  group('AstroTilt levels and movement', () {
    test('Loads three configured missions with a boss only in the finale', () {
      expect(astroTiltLevels.map((level) => level.id), [1, 2, 3]);
      expect(astroTiltLevels.map((level) => level.duration), [30, 40, 52]);
      expect(astroTiltLevels.map((level) => level.difficulty), [
        'FÁCIL',
        'MEDIO',
        'DIFÍCIL',
      ]);
      expect(astroTiltLevels.map((level) => level.hasBoss), [
        false,
        false,
        true,
      ]);
      expect(astroTiltLevel3.bossHealth, greaterThan(0));
    });

    test('Calibrates and smoothly moves in both sensor axes', () async {
      final sensor = _FakeAccelerometerService();
      final game = AstroTiltGame(
        level: astroTiltLevel1,
        accelerometerService: sensor,
      );
      game.setViewport(const Size(360, 760));
      expect(sensor.started, isTrue);
      sensor.emit(0, 0);
      expect(game.calibrate(), isTrue);
      _advance(game, 3.1);
      final start = game.playerPosition;

      for (var index = 0; index < 5; index++) {
        sensor.emit(-4, -4);
      }
      _advance(game, 0.8);
      expect(game.playerPosition.dx, greaterThan(start.dx));
      expect(game.playerPosition.dy, lessThan(start.dy));
      expect(
        game.velocity.distance,
        lessThanOrEqualTo(astroTiltLevel1.maxSpeed),
      );
      await game.close();
      expect(sensor.disposed, isTrue);
    });

    test('A moderate tilt moves the ship promptly after calibration', () async {
      final sensor = _FakeAccelerometerService();
      final game = AstroTiltGame(
        level: astroTiltLevel1,
        accelerometerService: sensor,
      );
      game.setViewport(const Size(360, 760));
      sensor.emit(0, 0);
      expect(game.calibrate(), isTrue);
      _advance(game, 3.1);
      final startX = game.playerPosition.dx;
      for (var index = 0; index < 8; index++) {
        sensor.emit(-1.1, 0);
      }
      _advance(game, 0.8);
      expect(game.playerPosition.dx - startX, greaterThan(50));
      expect(
        game.velocity.distance,
        lessThanOrEqualTo(astroTiltLevel1.maxSpeed),
      );
      await game.close();
    });

    test('Touch control can cross the play area at an agile pace', () async {
      final game = _readyGame(astroTiltLevel1);
      final startX = game.playerPosition.dx;
      game.setTouchInput(const Offset(1, 0));
      _advance(game, 0.5);
      expect(game.playerPosition.dx - startX, greaterThan(70));
      await game.close();
    });

    test('Keeps touch-controlled ship inside the play area', () async {
      final game = _readyGame(astroTiltLevel1);
      game.setTouchInput(const Offset(1, -1));
      _advance(game, 2);
      expect(game.playerPosition.dx, lessThanOrEqualTo(360 - 18));
      expect(game.playerPosition.dx, greaterThanOrEqualTo(18));
      expect(game.playerPosition.dy, greaterThanOrEqualTo(132 + 18));
      expect(game.playerPosition.dy, lessThanOrEqualTo(760 - 34 - 18));
      await game.close();
    });

    test('Fires automatically at the configured cadence', () async {
      final game = _readyGame(astroTiltLevel1);
      _advance(game, 0.6);
      expect(game.projectiles, isNotEmpty);
      expect(astroTiltLevel1.autoFireInterval, inInclusiveRange(0.35, 0.5));
      await game.close();
    });
  });

  group('AstroTilt combat', () {
    test(
      'Drone caps, fires weaker shots, expires, and freezes on pause',
      () async {
        final game = _readyGame(astroTiltLevel3);
        for (var i = 0; i < 3; i++) {
          game.spawnPowerUp(
            kind: AstroPowerUpKind.drone,
            position: game.playerPosition,
          );
          game.update(0.05);
        }
        expect(game.drones.length, 2);
        _advance(game, 0.7);
        expect(
          game.projectiles.any(
            (shot) => shot.kind == AstroProjectileKind.drone && shot.damage < 1,
          ),
          isTrue,
        );
        game.pause();
        final remaining = game.drones.first.remaining;
        final position = game.drones.first.position;
        _advance(game, 2);
        expect(game.drones.first.remaining, remaining);
        expect(game.drones.first.position, position);
        game.resume();
        _advance(game, 11);
        expect(game.drones, isEmpty);
        await game.close();
      },
    );

    test(
      'Triple shot launches three directions and missiles home then expire',
      () async {
        final game = _readyGame(astroTiltLevel2);
        game.spawnPowerUp(
          kind: AstroPowerUpKind.tripleShot,
          position: game.playerPosition,
        );
        game.update(0.05);
        _advance(game, 0.5);
        expect(
          game.projectiles
              .where((shot) => shot.fromPlayer)
              .any((shot) => shot.velocity.dx < 0),
          isTrue,
        );
        expect(
          game.projectiles
              .where((shot) => shot.fromPlayer)
              .any((shot) => shot.velocity.dx > 0),
          isTrue,
        );
        game.spawnPowerUp(
          kind: AstroPowerUpKind.missiles,
          position: game.playerPosition,
        );
        game.update(0.05);
        game.spawnEnemy(
          kind: AstroEnemyKind.basic,
          position: game.playerPosition + const Offset(70, -150),
          speed: 0,
        );
        _advance(game, 2.3);
        final missiles = game.projectiles
            .where((shot) => shot.kind == AstroProjectileKind.missile)
            .toList();
        expect(missiles, isNotEmpty);
        expect(missiles.first.velocity.dx, greaterThan(0));
        _advance(game, 3);
        expect(
          game.projectiles
              .where((shot) => shot.kind == AstroProjectileKind.missile)
              .every((shot) => shot.age < 2.8),
          isTrue,
        );
        await game.close();
      },
    );

    test('Special builds from kills, clears enemy shots, and damages boss without killing it', () async {
      final game = _readyGame(astroTiltLevel3);
      game.spawnEnemy(
        kind: AstroEnemyKind.basic,
        position: game.playerPosition - const Offset(0, 60),
        speed: 0,
      );
      _advance(game, 0.6);
      expect(game.specialEnergy, greaterThan(0));
      game.spawnPowerUp(
        kind: AstroPowerUpKind.energy,
        position: game.playerPosition,
      );
      game.update(0.05);
      game.spawnPowerUp(
        kind: AstroPowerUpKind.energy,
        position: game.playerPosition,
      );
      game.update(0.05);
      game.spawnPowerUp(
        kind: AstroPowerUpKind.energy,
        position: game.playerPosition,
      );
      game.update(0.05);
      expect(game.specialReady, isTrue);
      game.spawnBoss();
      final boss = game.boss!;
      final previousHealth = boss.health;
      game.projectiles.add(
        AstroProjectile(
          position: game.playerPosition,
          velocity: Offset.zero,
          radius: 5,
          fromPlayer: false,
        ),
      );
      expect(game.activateSpecial(), isTrue);
      expect(game.specialEnergy, 0);
      expect(game.projectiles.where((shot) => !shot.fromPlayer), isEmpty);
      expect(boss.health, previousHealth - 3);
      expect(game.boss, isNotNull);
      expect(game.activateSpecial(), isFalse);
      await game.close();
    });
    test('Bullets destroy enemies and award points and combo', () async {
      final game = _readyGame(astroTiltLevel1);
      final target = game.playerPosition - const Offset(0, 60);
      for (var index = 0; index < 4; index++) {
        game.spawnEnemy(
          kind: AstroEnemyKind.basic,
          position: target,
          speed: 0,
          radius: 14,
        );
      }
      _advance(game, 2.2);
      expect(game.enemiesDestroyed, greaterThanOrEqualTo(2));
      expect(game.score, greaterThan(0));
      expect(game.combo, greaterThanOrEqualTo(2));
      expect(game.maxCombo, greaterThanOrEqualTo(game.combo));
      expect(game.explosions, isNotEmpty);
      await game.close();
    });

    test('Meteorites can be destroyed by player shots', () async {
      final game = _readyGame(astroTiltLevel1);
      game.spawnMeteor(
        position: game.playerPosition - const Offset(0, 60),
        speed: 0,
        radius: 15,
      );
      _advance(game, 1);
      expect(game.meteorsDestroyed, 1);
      expect(game.meteors, isEmpty);
      await game.close();
    });

    test('Damage uses invulnerability and breaks the combo', () async {
      final game = _readyGame(astroTiltLevel1);
      final target = game.playerPosition - const Offset(0, 60);
      for (var index = 0; index < 4; index++) {
        game.spawnEnemy(
          kind: AstroEnemyKind.basic,
          position: target,
          speed: 0,
          radius: 14,
        );
      }
      _advance(game, 2.2);
      expect(game.combo, greaterThan(1));

      final originalHealth = game.health;
      game.damagePlayer();
      expect(game.health, lessThan(originalHealth));
      expect(game.combo, 1);
      expect(game.invulnerability, greaterThan(0));
      final damagedHealth = game.health;
      game.damagePlayer();
      expect(game.health, damagedHealth);
      _advance(game, 1.2);
      game.damagePlayer();
      expect(game.health, lessThan(damagedHealth));
      expect(game.combo, 1);
      await game.close();
    });

    test('Collects shield, double-shot, and repair power-ups', () async {
      final game = _readyGame(astroTiltLevel2);
      game.spawnPowerUp(
        kind: AstroPowerUpKind.shield,
        position: game.playerPosition,
      );
      game.update(0.05);
      expect(game.shieldActive, isTrue);
      final shieldedHealth = game.health;
      game.damagePlayer();
      expect(game.health, shieldedHealth);
      expect(game.shieldActive, isFalse);

      game.spawnPowerUp(
        kind: AstroPowerUpKind.doubleShot,
        position: game.playerPosition,
      );
      game.update(0.05);
      expect(game.doubleShotActive, isTrue);
      _advance(game, 0.5);
      expect(game.projectiles.length, greaterThanOrEqualTo(2));

      game.damagePlayer(40);
      _advance(game, 1.2);
      final lowHealth = game.health;
      game.spawnPowerUp(
        kind: AstroPowerUpKind.repair,
        position: game.playerPosition,
      );
      game.update(0.05);
      expect(game.health, greaterThan(lowHealth));
      await game.close();
    });

    test('Level three boss has phases, fires, and can be defeated', () async {
      final game = _readyGame(astroTiltLevel3);
      game.spawnBoss();
      final boss = game.boss!;
      expect(game.bossSpawned, isTrue);
      boss.health = boss.maxHealth ~/ 2;
      _advance(game, 1.1);
      expect(game.bossPhaseTwo, isTrue);
      expect(game.projectiles.any((shot) => !shot.fromPlayer), isTrue);

      boss.health = 1;
      game.projectiles.add(
        AstroProjectile(
          position: boss.position,
          velocity: Offset.zero,
          radius: 4,
        ),
      );
      game.update(0.01);
      expect(game.bossDefeated, isTrue);
      expect(game.boss, isNull);
      await game.close();
    });
  });

  group('AstroTilt flow', () {
    test('Victory audio event fires once across later updates', () async {
      final events = <AstroAudioEvent>[];
      final sensor = _FakeAccelerometerService();
      final game = AstroTiltGame(
        level: astroTiltLevel1,
        accelerometerService: sensor,
        onAudioEvent: events.add,
      );
      game.setViewport(const Size(360, 760));
      game.setTouchMode(true);
      expect(game.calibrate(), isTrue);
      _advance(game, 3.1 + astroTiltLevel1.duration + 1);
      expect(
        events.where((event) => event == AstroAudioEvent.victory).length,
        1,
      );
      await game.close();
    });
    test('Pausing freezes timers and movement until resumed', () async {
      final game = _readyGame(astroTiltLevel1);
      game.setTouchInput(const Offset(1, 0));
      _advance(game, 0.2);
      game.pause();
      final elapsed = game.elapsed;
      final position = game.playerPosition;
      _advance(game, 1);
      expect(game.phase, AstroTiltPhase.paused);
      expect(game.elapsed, elapsed);
      expect(game.playerPosition, position);
      game.resume();
      _advance(game, 0.2);
      expect(game.elapsed, greaterThan(elapsed));
      await game.close();
    });

    test(
      'Paused sensor readings do not cause a movement jump on resume',
      () async {
        final sensor = _FakeAccelerometerService();
        final game = AstroTiltGame(
          level: astroTiltLevel1,
          accelerometerService: sensor,
        );
        game.setViewport(const Size(360, 760));
        sensor.emit(0, 0);
        expect(game.calibrate(), isTrue);
        _advance(game, 3.1);
        sensor.emit(-4, -4);
        _advance(game, 0.2);
        game.pause();
        final position = game.playerPosition;
        sensor.emit(-20, -20);
        _advance(game, 2);
        game.resume();
        _advance(game, 0.1);
        expect(game.playerPosition, position);
        sensor.emit(-4, -4);
        _advance(game, 0.2);
        expect(game.playerPosition.dx, greaterThan(position.dx));
        await game.close();
      },
    );

    test('Completes a regular mission and rates the result', () async {
      final game = _readyGame(astroTiltLevel1);
      _advance(game, astroTiltLevel1.duration);
      expect(game.phase, AstroTiltPhase.victory);
      expect(game.victoryMessage, '¡PATRULLA COMPLETADA!');
      expect(game.stars, inInclusiveRange(1, 3));
      await game.close();
    });

    test('Losing all health ends the mission', () async {
      final game = _readyGame(astroTiltLevel1);
      for (var hit = 0; hit < 5; hit++) {
        game.damagePlayer(25);
        _advance(game, 1.2);
      }
      expect(game.health, 0);
      expect(game.phase, AstroTiltPhase.defeated);
      await game.close();
    });

    test('Completes the final level only after defeating its boss', () async {
      final game = _readyGame(astroTiltLevel3);
      _advance(
        game,
        astroTiltLevel3.duration - astroTiltLevel3.bossWindow + 0.2,
      );
      expect(game.bossSpawned, isTrue);
      expect(game.phase, AstroTiltPhase.playing);
      final boss = game.boss!;
      boss.health = 1;
      game.projectiles.add(
        AstroProjectile(
          position: boss.position,
          velocity: Offset.zero,
          radius: 4,
        ),
      );
      game.update(0.01);
      expect(game.bossDefeated, isTrue);
      _advance(game, astroTiltLevel3.duration);
      expect(game.phase, AstroTiltPhase.victory);
      expect(game.victoryMessage, '¡ASTROTILT COMPLETADO!');
      await game.close();
    });

    test(
      'Next-level configuration advances and has no level after the finale',
      () {
        expect(nextAstroTiltLevel(astroTiltLevel1), astroTiltLevel2);
        expect(nextAstroTiltLevel(astroTiltLevel2), astroTiltLevel3);
        expect(nextAstroTiltLevel(astroTiltLevel3), isNull);
      },
    );

    testWidgets('Lifecycle pauses, continues, and disposes the sensor', (
      tester,
    ) async {
      final sensor = _FakeAccelerometerService();
      await tester.pumpWidget(
        MaterialApp(
          home: AstroTiltScreen(
            level: astroTiltLevel1,
            accelerometerService: sensor,
          ),
        ),
      );
      sensor.emit(0, 0);
      await tester.tap(find.text('CALIBRAR'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('MISIÓN EN PAUSA'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.tap(find.text('CONTINUAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('MISIÓN EN PAUSA'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
