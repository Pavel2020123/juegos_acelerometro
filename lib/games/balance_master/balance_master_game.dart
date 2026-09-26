import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/sensors/accelerometer_service.dart';
import 'balance_master_level.dart';

enum BalancePhase { calibrating, countdown, playing, falling, lost, won }

class BalanceHudState {
  const BalanceHudState({
    required this.phase,
    required this.elapsed,
    required this.duration,
    required this.stability,
    required this.averageStability,
    required this.countdown,
    required this.impulseWarning,
  });

  final BalancePhase phase;
  final double elapsed;
  final double duration;
  final double stability;
  final double averageStability;
  final double countdown;
  final bool impulseWarning;
}

class BalanceObjectState {
  BalanceObjectState({
    required this.x,
    required this.radius,
    required this.response,
  });

  double x;
  double velocity = 0;
  final double radius;
  final double response;
}

class BalanceMasterGame extends FlameGame {
  BalanceMasterGame({
    required this.level,
    AccelerometerService? accelerometerService,
  }) : _accelerometerService = accelerometerService ?? AccelerometerService(),
       hud = ValueNotifier(
         BalanceHudState(
           phase: BalancePhase.calibrating,
           elapsed: 0,
           duration: level.duration,
           stability: 100,
           averageStability: 100,
           countdown: 3.6,
           impulseWarning: false,
         ),
       );

  final BalanceMasterLevel level;
  final AccelerometerService _accelerometerService;
  final ValueNotifier<BalanceHudState> hud;
  final ValueNotifier<bool> sensorAvailable = ValueNotifier(false);
  final List<BalanceObjectState> objects = [];

  StreamSubscription<AccelerometerReading>? _subscription;
  AccelerometerReading? _lastReading;
  AccelerometerReading? _lastVariationReading;
  bool _closed = false;
  bool _ignoreReadings = false;
  bool _touchMode = false;
  bool _initialized = false;
  double _neutralX = 0;
  double _neutralY = 0;
  double _filteredTilt = 0;
  double _touchTilt = 0;
  double _visualTilt = 0;
  double _motionSpike = 0;
  double _stability = 100;
  double _stabilityIntegral = 0;
  double _elapsed = 0;
  double _countdown = 3.6;
  double _fallProgress = 0;
  double _hudTimer = 0;
  double _nextImpulseAt = 0;
  int _impulseIndex = 0;
  int? _fallingIndex;
  BalancePhase _phase = BalancePhase.calibrating;

  bool get touchMode => _touchMode;
  BalancePhase get phase => _phase;
  double get neutralX => _neutralX;
  double get neutralY => _neutralY;
  double get platformWidth => math.min(size.x * level.platformWidthFactor, 440);

  @override
  Color backgroundColor() => const Color(0xFF050914);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (_closed) return;
    _ensureObjects();
    _subscription = _accelerometerService.readings.listen(
      _onReading,
      onError: (Object error) {
        if (_closed) return;
        sensorAvailable.value = false;
        _filteredTilt = 0;
      },
    );
    _accelerometerService.start();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_closed) _ensureObjects();
  }

  void _ensureObjects() {
    if (_initialized || size.x <= 0 || size.y <= 0) return;
    _initialized = true;
    _resetObjects();
  }

  void _resetObjects() {
    objects.clear();
    final starts = switch (level.objectCount) {
      1 => [0.0],
      2 => [-0.18, 0.18],
      _ => [-0.27, 0.0, 0.27],
    };
    const responses = [1.0, 0.82, 1.12];
    const radii = [15.0, 13.0, 12.0];
    for (var i = 0; i < level.objectCount; i++) {
      objects.add(
        BalanceObjectState(
          x: platformWidth * starts[i],
          radius: radii[i],
          response: responses[i],
        ),
      );
    }
  }

  void _onReading(AccelerometerReading reading) {
    if (_closed || _ignoreReadings) return;
    _lastReading = reading;
    if (!sensorAvailable.value) sensorAvailable.value = true;
    if (_touchMode) return;
    final previous = _lastVariationReading;
    _lastVariationReading = reading;
    if (previous != null && _phase == BalancePhase.playing) {
      final dx = reading.x - previous.x;
      final dy = reading.y - previous.y;
      _motionSpike = math.max(_motionSpike, math.sqrt(dx * dx + dy * dy));
    }
    // Keep the same X direction used by Tilt Maze. Y is retained for
    // calibration and the stability metric, not for horizontal movement.
    final target = (-(reading.x - _neutralX)).clamp(-2.5, 2.5);
    _filteredTilt += (target - _filteredTilt) * 0.16;
  }

  void setTouchMode(bool enabled) {
    if (_touchMode == enabled) return;
    _touchMode = enabled;
    _touchTilt = 0;
    _filteredTilt = 0;
    _motionSpike = 0;
    _lastVariationReading = null;
    for (final object in objects) {
      object.velocity = 0;
    }
  }

  void setTouchTilt(double value) {
    if (!_touchMode || _phase != BalancePhase.playing || paused) return;
    final next = value.clamp(-1.0, 1.0);
    _motionSpike = math.max(_motionSpike, (next - _touchTilt).abs() * 0.35);
    _touchTilt = next;
  }

  bool calibrate() {
    if (_phase != BalancePhase.calibrating) return false;
    if (!_touchMode && (!sensorAvailable.value || _lastReading == null)) {
      return false;
    }
    _neutralX = _lastReading?.x ?? 0;
    _neutralY = _lastReading?.y ?? 0;
    _filteredTilt = 0;
    _touchTilt = 0;
    _motionSpike = 0;
    _lastVariationReading = _lastReading;
    _countdown = 3.6;
    _phase = BalancePhase.countdown;
    _publishHud();
    return true;
  }

  void restart() {
    _ensureObjects();
    _resetObjects();
    _phase = BalancePhase.calibrating;
    _elapsed = 0;
    _countdown = 3.6;
    _fallProgress = 0;
    _fallingIndex = null;
    _stability = 100;
    _stabilityIntegral = 0;
    _filteredTilt = 0;
    _touchTilt = 0;
    _visualTilt = 0;
    _motionSpike = 0;
    _nextImpulseAt = level.perturbationInterval;
    _impulseIndex = 0;
    _publishHud();
  }

  void pausePlay() {
    _ignoreReadings = true;
    _touchTilt = 0;
    pauseEngine();
  }

  void resumePlay() {
    _filteredTilt = 0;
    _touchTilt = 0;
    _motionSpike = 0;
    _lastVariationReading = null;
    for (final object in objects) {
      object.velocity = 0;
    }
    _ignoreReadings = false;
    resumeEngine();
  }

  @override
  void update(double dt) {
    if (_closed || paused) return;
    dt = dt.clamp(0.0, 0.05);
    super.update(dt);
    if (!_initialized) return;
    if (!_touchMode &&
        !sensorAvailable.value &&
        (_phase == BalancePhase.countdown || _phase == BalancePhase.playing)) {
      return;
    }

    if (_phase == BalancePhase.countdown) {
      _countdown -= dt;
      if (_countdown <= 0) {
        _countdown = 0;
        _phase = BalancePhase.playing;
        _filteredTilt = 0;
        _touchTilt = 0;
        _motionSpike = 0;
        _nextImpulseAt = level.perturbationInterval;
      }
      _publishAtInterval(dt);
      return;
    }
    if (_phase == BalancePhase.falling) {
      _fallProgress += dt;
      if (_fallProgress >= 0.65) {
        _phase = BalancePhase.lost;
        _publishHud();
      }
      return;
    }
    if (_phase != BalancePhase.playing) return;

    final activeDt = math.min(dt, level.duration - _elapsed);
    _elapsed += activeDt;
    final rawTilt = _touchMode ? _touchTilt * 1.2 : _filteredTilt;
    final tilt = rawTilt.abs() < 0.10
        ? 0.0
        : (rawTilt.sign * (rawTilt.abs() - 0.10)).clamp(-2.2, 2.2);
    _visualTilt += (tilt * 0.036 - _visualTilt) * (dt * 5).clamp(0.0, 1.0);

    _motionSpike *= math.exp(-2.6 * dt);
    final stabilityTarget = (100 - _motionSpike * 30 - tilt.abs() * 6).clamp(
      20.0,
      100.0,
    );
    _stability += (stabilityTarget - _stability) * (1 - math.exp(-2.2 * dt));
    _stabilityIntegral += _stability * activeDt;

    if (level.perturbationInterval > 0 && _elapsed >= _nextImpulseAt) {
      final impulse = _impulseIndex.isEven ? 13.0 : -13.0;
      for (final object in objects) {
        object.velocity += impulse * object.response;
      }
      _impulseIndex++;
      _nextImpulseAt += level.perturbationInterval;
    }

    final safeHalfWidth = platformWidth / 2 - level.hazardInset;
    for (var i = 0; i < objects.length; i++) {
      final object = objects[i];
      object.velocity += tilt * level.sensitivity * object.response * dt;
      object.velocity *= math.exp(-level.friction * dt);
      object.velocity = object.velocity.clamp(-level.maxSpeed, level.maxSpeed);
      object.x += object.velocity * dt;
      if (object.x.abs() + object.radius > safeHalfWidth) {
        _fallingIndex = i;
        _fallProgress = 0;
        _phase = BalancePhase.falling;
        _publishHud();
        return;
      }
    }

    if (_elapsed >= level.duration) {
      _phase = BalancePhase.won;
      _publishHud();
      return;
    }
    _publishAtInterval(dt);
  }

  void _publishAtInterval(double dt) {
    _hudTimer += dt;
    if (_hudTimer >= 0.05) {
      _hudTimer = 0;
      _publishHud();
    }
  }

  void _publishHud() {
    if (_closed) return;
    hud.value = BalanceHudState(
      phase: _phase,
      elapsed: _elapsed,
      duration: level.duration,
      stability: _stability,
      averageStability: _elapsed > 0 ? _stabilityIntegral / _elapsed : 100,
      countdown: _countdown,
      impulseWarning:
          _phase == BalancePhase.playing &&
          level.perturbationInterval > 0 &&
          _elapsed >= _nextImpulseAt - 1 &&
          _elapsed < _nextImpulseAt,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    _drawBackground(canvas);
    final platformY = size.y * 0.55;
    final platformX =
        size.x / 2 +
        (level.id == 3 && _phase == BalancePhase.playing
            ? math.sin(_elapsed * 0.8) * 5
            : 0);
    canvas.save();
    canvas.translate(platformX, platformY);
    canvas.rotate(_visualTilt.clamp(-0.08, 0.08));
    _drawPlatform(canvas);
    for (var i = 0; i < objects.length; i++) {
      _drawObject(canvas, objects[i], i);
    }
    canvas.restore();
  }

  void _drawBackground(Canvas canvas) {
    final grid = Paint()
      ..color = const Color(0xFF2A4360).withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (double x = 0; x < size.x; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), grid);
    }
    for (double y = 0; y < size.y; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), grid);
    }
    final star = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (var i = 0; i < 38; i++) {
      final x = ((i * 137 + 29) % 997) / 997 * size.x;
      final y = ((i * 223 + 71) % 991) / 991 * size.y;
      canvas.drawCircle(Offset(x, y), i % 7 == 0 ? 1.5 : 0.8, star);
    }
  }

  void _drawPlatform(Canvas canvas) {
    final half = platformWidth / 2;
    final shadow = RRect.fromRectAndRadius(
      Rect.fromLTWH(-half + 5, 16, platformWidth, 22),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      shadow,
      Paint()
        ..color = const Color(0xFF02040B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-half, 0, platformWidth, 23),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFF0B2440),
    );
    final top = RRect.fromRectAndRadius(
      Rect.fromLTWH(-half, -11, platformWidth, 24),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      top,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF275575), Color(0xFF142B48), Color(0xFF37617A)],
        ).createShader(Rect.fromLTWH(-half, -11, platformWidth, 24)),
    );
    canvas.drawRRect(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF55DBEF),
    );
    canvas.drawLine(
      Offset(-half + 14, -8),
      Offset(half - 14, -8),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      const Offset(0, 1),
      5,
      Paint()..color = const Color(0xFFB8F5FF),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(side * (half - 16), 1),
        3,
        Paint()..color = const Color(0xFF42D9ED),
      );
    }
    if (level.hazardInset > 0) {
      final hazardPaint = Paint()..color = const Color(0xFFFF6A86);
      for (final side in [-1.0, 1.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(side * (half - level.hazardInset / 2), -1),
              width: level.hazardInset,
              height: 13,
            ),
            const Radius.circular(3),
          ),
          hazardPaint,
        );
      }
    }
  }

  void _drawObject(Canvas canvas, BalanceObjectState object, int index) {
    final falling = _phase == BalancePhase.falling && _fallingIndex == index;
    final progress = falling ? _fallProgress / 0.65 : 0.0;
    final radius = object.radius * (1 - progress * 0.65);
    final center = Offset(object.x, -object.radius - 12 + progress * 125);
    final color = switch (index) {
      0 => const Color(0xFF8F7BFF),
      1 => const Color(0xFF50DDEB),
      _ => const Color(0xFF7BEEAF),
    };
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(object.x + 3, -7),
        width: object.radius * 2.1,
        height: 7,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.32),
    );
    canvas.drawCircle(
      center,
      radius + 8,
      Paint()
        ..color = color.withValues(alpha: (0.20 * (1 - progress)).clamp(0, 1))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    if (index == 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCircle(center: center, radius: radius),
          const Radius.circular(7),
        ),
        Paint()..color = color.withValues(alpha: 1 - progress),
      );
    } else {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: 1 - progress),
      );
    }
    canvas.drawCircle(
      center.translate(-radius * 0.3, -radius * 0.35),
      radius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.72 * (1 - progress)),
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    pauseEngine();
    await _subscription?.cancel();
    _subscription = null;
    await _accelerometerService.dispose();
    sensorAvailable.dispose();
    hud.dispose();
  }

  @override
  void onRemove() {
    unawaited(close());
    super.onRemove();
  }

  @override
  void onDispose() {
    unawaited(close());
    dispose();
    super.onDispose();
  }
}
