import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_acelerometro/core/sensors/gyroscope_service.dart';
import 'package:juegos_acelerometro/games/gyro_aim/gyro_aim_game.dart';

class _FakeGyroscopeService extends GyroscopeService {
  _FakeGyroscopeService()
    : _controller = StreamController<GyroscopeReading>.broadcast(sync: true),
      super();

  final StreamController<GyroscopeReading> _controller;
  bool started = false;
  bool stopped = false;
  bool disposed = false;

  @override
  Stream<GyroscopeReading> get readings => _controller.stream;

  @override
  void start() => started = true;

  @override
  Future<void> stop() async => stopped = true;

  void emit(double x, double y, double z) {
    _controller.add(GyroscopeReading(x: x, y: y, z: z));
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}

void _calibrate(GyroAimGame game, _FakeGyroscopeService service) {
  game.begin();
  service.emit(0, 0, 0);
  game.update(.7);
  expect(game.phase, GyroAimPhase.playing);
}

void main() {
  test(
    'Integrates portrait gyro axes, dead zone and clamps long intervals',
    () async {
      final service = _FakeGyroscopeService();
      final game = GyroAimGame(gyroscopeService: service);
      game.setViewport(const Size(360, 700));
      _calibrate(game, service);
      final start = game.aimPosition;

      game.integrateForTest(const GyroscopeReading(x: 0, y: 1, z: 0), .1);
      expect(game.aimPosition.dx, greaterThan(start.dx));
      final afterYaw = game.aimPosition;
      game.integrateForTest(const GyroscopeReading(x: 1, y: 0, z: 0), .1);
      expect(game.aimPosition.dy, lessThan(afterYaw.dy));
      final beforeDeadZone = game.aimPosition;
      game.integrateForTest(const GyroscopeReading(x: .02, y: .02, z: 0), .1);
      expect(game.aimPosition, beforeDeadZone);

      game.integrateForTest(const GyroscopeReading(x: 0, y: 2, z: 0), 4);
      expect(game.aimPosition.dx, lessThanOrEqualTo(340));
      await game.close();
    },
  );

  test(
    'Calibration removes stationary bias and recenter clears drift',
    () async {
      final service = _FakeGyroscopeService();
      final game = GyroAimGame(gyroscopeService: service);
      game.setViewport(const Size(360, 700));
      game.begin();
      service.emit(.2, -.15, .1);
      game.update(.7);
      final start = game.aimPosition;
      game.integrateForTest(const GyroscopeReading(x: .2, y: -.15, z: .1), .1);
      expect(game.aimPosition, start);
      game.setSensitivity(2.2);
      expect(game.sensitivity, 2.2);
      game.centerAim();
      expect(game.aimPosition.dx, 180);
      expect(game.aimPosition.dy, 360);
      await game.close();
    },
  );

  test('Hits, misses, scores and calculates precision', () async {
    final service = _FakeGyroscopeService();
    final audioEvents = <GyroAimAudioEvent>[];
    final game = GyroAimGame(
      gyroscopeService: service,
      onAudioEvent: audioEvents.add,
    );
    game.setViewport(const Size(360, 700));
    _calibrate(game, service);
    final target = game.target!;
    game.setAimForTest(target.position);
    game.fire();
    expect(game.score, 10);
    expect(game.hits, 1);
    expect(game.shots, 1);
    expect(game.accuracy, 100);
    game.setAimForTest(const Offset(22, 158));
    game.fire();
    expect(game.score, 10);
    expect(game.shots, 2);
    expect(game.accuracy, 50);
    expect(audioEvents, [GyroAimAudioEvent.shot, GyroAimAudioEvent.shot]);
    await game.close();
  });

  test('Pause freezes time, resume avoids accumulated sensor input, and results stop listening', () async {
    final service = _FakeGyroscopeService();
    final game = GyroAimGame(gyroscopeService: service);
    game.setViewport(const Size(360, 700));
    _calibrate(game, service);
    game.update(1);
    game.pause();
    final elapsed = game.elapsed;
    final position = game.aimPosition;
    game.update(10);
    service.emit(0, 3, 0);
    expect(game.elapsed, elapsed);
    expect(game.aimPosition, position);
    game.resume();
    game.update(.1);
    expect(game.elapsed, greaterThan(elapsed));
    game.update(29);
    expect(game.phase, GyroAimPhase.results);
    await Future<void>.delayed(Duration.zero);
    expect(service.stopped, isTrue);
    game.restart();
    expect(game.phase, GyroAimPhase.calibrating);
    expect(game.isListening, isTrue);
    await game.close();
    expect(service.disposed, isTrue);
  });

  test('Missing sensor data produces a usable error state', () async {
    final service = _FakeGyroscopeService();
    final game = GyroAimGame(gyroscopeService: service);
    game.setViewport(const Size(360, 700));
    game.begin();
    game.update(.7);
    expect(game.phase, GyroAimPhase.error);
    expect(game.sensorAvailable, isFalse);
    await game.close();
  });
}
