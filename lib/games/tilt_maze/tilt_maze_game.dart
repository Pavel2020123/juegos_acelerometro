import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../../core/sensors/accelerometer_service.dart';

class TiltMazeGame extends FlameGame {
  TiltMazeGame({AccelerometerService? accelerometerService})
    : _accelerometerService = accelerometerService ?? AccelerometerService();

  static const double _ballRadius = 28;
  static const double _sensitivity = 180;
  static const double _friction = 4.5;
  static const double _deadZone = 0.15;
  static const double _maxSpeed = 500;
  static const double _bounce = 0.35;

  // Change either value to -1 when testing a different device orientation.
  static const double xDirection = 1;
  static const double yDirection = 1;

  final AccelerometerService _accelerometerService;
  final ValueNotifier<AccelerometerReading> currentReading =
      ValueNotifier<AccelerometerReading>(
        const AccelerometerReading(x: 0, y: 0, z: 0, magnitude: 0),
      );

  StreamSubscription<AccelerometerReading>? _readingSubscription;
  CircleComponent? _ball;
  Vector2 _velocity = Vector2.zero();
  Vector2 _smoothedAcceleration = Vector2.zero();
  bool _ballPositioned = false;
  bool _closed = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final ball = CircleComponent(
      radius: _ballRadius,
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0xff6c4cff),
    );
    _ball = ball;
    add(ball);

    _readingSubscription = _accelerometerService.readings.listen((reading) {
      currentReading.value = reading;
      _smoothedAcceleration = Vector2(
        _smoothAxis(_smoothedAcceleration.x, reading.x * xDirection),
        _smoothAxis(_smoothedAcceleration.y, reading.y * yDirection),
      );
    });
    _accelerometerService.start();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final ball = _ball;
    if (ball == null) {
      return;
    }

    if (!_ballPositioned && size.x > 0 && size.y > 0) {
      ball.position = size / 2;
      _ballPositioned = true;
    }
    if (_ballPositioned) {
      _keepBallInside();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final ball = _ball;
    if (!_ballPositioned || ball == null) {
      return;
    }

    final seconds = dt.clamp(0.0, 0.05);
    final input = Vector2(
      _applyDeadZone(_smoothedAcceleration.x),
      _applyDeadZone(_smoothedAcceleration.y),
    );

    _velocity += input * _sensitivity * seconds;
    final damping = math.exp(-_friction * seconds);
    _velocity *= damping;

    if (_velocity.length > _maxSpeed) {
      _velocity = _velocity.normalized() * _maxSpeed;
    }

    ball.position += _velocity * seconds;
    _keepBallInside();
  }

  double _smoothAxis(double previous, double current) {
    const smoothing = 0.15;
    return previous + (current - previous) * smoothing;
  }

  double _applyDeadZone(double value) {
    if (value.abs() < _deadZone) {
      return 0;
    }
    return value;
  }

  void _keepBallInside() {
    final ball = _ball;
    if (ball == null) {
      return;
    }

    final minX = _ballRadius;
    final maxX = size.x - _ballRadius;
    final minY = _ballRadius;
    final maxY = size.y - _ballRadius;

    if (ball.position.x < minX) {
      ball.position.x = minX;
      _velocity.x = _velocity.x.abs() * _bounce;
    } else if (ball.position.x > maxX) {
      ball.position.x = maxX;
      _velocity.x = -_velocity.x.abs() * _bounce;
    }

    if (ball.position.y < minY) {
      ball.position.y = minY;
      _velocity.y = _velocity.y.abs() * _bounce;
    } else if (ball.position.y > maxY) {
      ball.position.y = maxY;
      _velocity.y = -_velocity.y.abs() * _bounce;
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _readingSubscription?.cancel();
    _readingSubscription = null;
    await _accelerometerService.dispose();
    currentReading.dispose();
  }

  @override
  void onRemove() {
    unawaited(close());
    super.onRemove();
  }
}
