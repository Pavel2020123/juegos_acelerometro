import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/sensors/accelerometer_service.dart';
import 'balance_master_level.dart';

enum BalancePhase { calibrating, countdown, playing, falling, lost, won }

int balanceStars({
  required double averageStability,
  required int objectivesCompleted,
  required int totalObjectives,
}) {
  if (averageStability < 65) return 1;
  final needed = (totalObjectives * 0.65).ceil();
  if (averageStability >= 84 && objectivesCompleted >= needed) return 3;
  return 2;
}

class BalanceHudState {
  const BalanceHudState({
    required this.phase,
    required this.elapsed,
    required this.duration,
    required this.stability,
    required this.averageStability,
    required this.countdown,
    required this.impulseWarning,
    required this.gustFromLeft,
    required this.platformWarning,
    required this.score,
    required this.combo,
    required this.maxCombo,
    required this.objectiveIndex,
    required this.objectiveProgress,
    required this.objectivesCompleted,
    required this.totalObjectives,
    required this.objectiveCompletedPulse,
    required this.stars,
  });

  final BalancePhase phase;
  final double elapsed;
  final double duration;
  final double stability;
  final double averageStability;
  final double countdown;
  final bool impulseWarning;
  final bool gustFromLeft;
  final bool platformWarning;
  final int score;
  final int combo;
  final int maxCombo;
  final int? objectiveIndex;
  final double objectiveProgress;
  final int objectivesCompleted;
  final int totalObjectives;
  final bool objectiveCompletedPulse;
  final int stars;
}

class BalanceObjectState {
  BalanceObjectState({
    required this.x,
    required this.radius,
    required this.response,
    required this.frictionFactor,
  });

  double x;
  double velocity = 0;
  final double radius;
  final double response;
  final double frictionFactor;
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
           gustFromLeft: true,
           platformWarning: false,
           score: 0,
           combo: 1,
           maxCombo: 1,
           objectiveIndex: null,
           objectiveProgress: 0,
           objectivesCompleted: 0,
           totalObjectives: level.objectives.length,
           objectiveCompletedPulse: false,
           stars: 0,
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
  double _nextPlatformAt = 0;
  double _platformShift = 0;
  double _platformMotionStart = -1;
  int _platformMotionIndex = 0;
  int _nextObjective = 0;
  BalanceObjective? _activeObjective;
  double _objectiveStartedAt = 0;
  double _objectiveProgress = 0;
  int _objectivesCompleted = 0;
  double _objectivePulse = 0;
  double _completedObjectiveCenter = 0;
  double _stableComboTime = 0;
  int _combo = 1;
  int _maxCombo = 1;
  double _score = 0;
  int? _fallingIndex;
  BalancePhase _phase = BalancePhase.calibrating;

  bool get touchMode => _touchMode;
  BalancePhase get phase => _phase;
  double get neutralX => _neutralX;
  double get neutralY => _neutralY;
  double get platformWidth => math.min(size.x * level.platformWidthFactor, 440);
  BalanceObjective? get activeObjective => _activeObjective;
  double get platformShift => _platformShift;

  @override
  Color backgroundColor() => const Color(0xFF18243A);

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
    const responses = [1.0, 0.78, 1.17];
    const frictionFactors = [1.0, 0.78, 1.26];
    const radii = [15.0, 13.0, 12.0];
    for (var i = 0; i < level.objectCount; i++) {
      objects.add(
        BalanceObjectState(
          x: platformWidth * starts[i],
          radius: radii[i],
          response: responses[i],
          frictionFactor: frictionFactors[i],
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
    _motionSpike = math.max(_motionSpike, (next - _touchTilt).abs() * 0.65);
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
    _nextPlatformAt = level.dynamicPlatformInterval;
    _platformShift = 0;
    _platformMotionStart = -1;
    _platformMotionIndex = 0;
    _nextObjective = 0;
    _activeObjective = null;
    _objectiveProgress = 0;
    _objectivesCompleted = 0;
    _objectivePulse = 0;
    _completedObjectiveCenter = 0;
    _stableComboTime = 0;
    _combo = 1;
    _maxCombo = 1;
    _score = 0;
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
        _nextPlatformAt = level.dynamicPlatformInterval;
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
    _objectivePulse = math.max(0, _objectivePulse - dt);
    final platformDelta = _updatePlatformMotion();
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
    _updateCombo(activeDt);
    _score += level.scorePerSecond * activeDt * _combo;

    if (level.perturbationInterval > 0 && _elapsed >= _nextImpulseAt) {
      final impulse = _impulseIndex.isEven
          ? level.gustImpulse
          : -level.gustImpulse;
      for (final object in objects) {
        object.velocity += impulse * object.response;
      }
      _impulseIndex++;
      _nextImpulseAt += level.perturbationInterval;
    }

    final safeHalfWidth = platformWidth / 2 - level.hazardInset;
    for (var i = 0; i < objects.length; i++) {
      final object = objects[i];
      final edgeClearance = safeHalfWidth - object.x.abs() - object.radius;
      if (edgeClearance > 12) {
        object.velocity -=
            platformDelta * level.platformInertia * object.response;
      }
      object.velocity += tilt * level.sensitivity * object.response * dt;
      object.velocity *= math.exp(-level.friction * object.frictionFactor * dt);
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

    _updateObjective(activeDt);

    if (_elapsed >= level.duration) {
      _phase = BalancePhase.won;
      _publishHud();
      return;
    }
    _publishAtInterval(dt);
  }

  void _updateCombo(double dt) {
    if (_motionSpike >= level.comboBreakSpike ||
        _stability < level.comboBreakThreshold) {
      _stableComboTime = 0;
      _combo = 1;
      return;
    }
    if (_stability < level.comboThreshold) return;
    _stableComboTime += dt;
    _combo = math.min(
      4,
      1 + (_stableComboTime / level.comboStepSeconds).floor(),
    );
    _maxCombo = math.max(_maxCombo, _combo);
  }

  double _updatePlatformMotion() {
    if (level.dynamicPlatformInterval <= 0) return 0;
    final previousShift = _platformShift;
    if (_elapsed >= _nextPlatformAt) {
      _platformMotionStart = _nextPlatformAt;
      _nextPlatformAt += level.dynamicPlatformInterval;
      _platformMotionIndex++;
    }
    final phaseTime = _elapsed - _platformMotionStart;
    if (_platformMotionStart >= 0 &&
        phaseTime >= 0 &&
        phaseTime < level.platformMotionSeconds) {
      final direction = _platformMotionIndex.isOdd ? 1.0 : -1.0;
      _platformShift =
          direction *
          level.platformShift *
          math.sin(math.pi * phaseTime / level.platformMotionSeconds);
    } else {
      _platformShift = 0;
    }
    return _platformShift - previousShift;
  }

  double _objectiveCenter(BalanceObjective objective) {
    final halfZone = platformWidth * objective.widthFactor / 2;
    final safeHalf = platformWidth / 2 - level.hazardInset;
    return (platformWidth * objective.centerFactor).clamp(
      -safeHalf + halfZone + 4,
      safeHalf - halfZone - 4,
    );
  }

  void _updateObjective(double dt) {
    if (_activeObjective == null &&
        _nextObjective < level.objectives.length &&
        _elapsed >= level.objectives[_nextObjective].appearAt) {
      _activeObjective = level.objectives[_nextObjective];
      _objectiveStartedAt = _elapsed;
      _objectiveProgress = 0;
      _nextObjective++;
    }
    final objective = _activeObjective;
    if (objective == null) return;
    if (_elapsed - _objectiveStartedAt >= objective.availableSeconds) {
      _activeObjective = null;
      _objectiveProgress = 0;
      return;
    }
    final object = objects[objective.objectIndex];
    final halfZone = platformWidth * objective.widthFactor / 2;
    final inside =
        (object.x - _objectiveCenter(objective)).abs() + object.radius <=
        halfZone;
    _objectiveProgress = (_objectiveProgress + (inside ? dt : -dt * 0.5)).clamp(
      0,
      objective.holdSeconds,
    );
    if (_objectiveProgress >= objective.holdSeconds) {
      _objectivesCompleted++;
      _score += level.objectiveBonus * _combo;
      _objectivePulse = 1.2;
      _completedObjectiveCenter = _objectiveCenter(objective);
      _activeObjective = null;
      _objectiveProgress = 0;
    }
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
          _elapsed >= _nextImpulseAt - level.gustWarningSeconds &&
          _elapsed < _nextImpulseAt,
      gustFromLeft: _impulseIndex.isEven,
      platformWarning:
          _phase == BalancePhase.playing &&
          level.dynamicPlatformInterval > 0 &&
          _elapsed >= _nextPlatformAt - level.platformWarningSeconds &&
          _elapsed < _nextPlatformAt,
      score: _score.round(),
      combo: _combo,
      maxCombo: _maxCombo,
      objectiveIndex: _activeObjective?.objectIndex,
      objectiveProgress: _activeObjective == null
          ? 0
          : _objectiveProgress / _activeObjective!.holdSeconds,
      objectivesCompleted: _objectivesCompleted,
      totalObjectives: level.objectives.length,
      objectiveCompletedPulse: _objectivePulse > 0,
      stars: _phase == BalancePhase.won
          ? balanceStars(
              averageStability: _elapsed > 0
                  ? _stabilityIntegral / _elapsed
                  : 100,
              objectivesCompleted: _objectivesCompleted,
              totalObjectives: level.objectives.length,
            )
          : 0,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    _drawBackground(canvas);
    final platformY = size.y * 0.55;
    final platformX = size.x / 2 + _platformShift;
    canvas.save();
    canvas.translate(platformX, platformY);
    canvas.rotate(_visualTilt.clamp(-0.08, 0.08));
    _drawPlatform(canvas);
    _drawObjective(canvas);
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

  void _drawObjective(Canvas canvas) {
    final objective = _activeObjective;
    if (objective != null && _phase == BalancePhase.playing) {
      final center = _objectiveCenter(objective);
      final width = platformWidth * objective.widthFactor;
      final zone = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center, 0), width: width, height: 31),
        const Radius.circular(10),
      );
      canvas.drawRRect(
        zone,
        Paint()
          ..color = const Color(0xFF49E8B7).withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawRRect(
        zone,
        Paint()..color = const Color(0xFF53E7C1).withValues(alpha: 0.25),
      );
      canvas.drawRRect(
        zone,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF8DFFE3),
      );
      final progressWidth =
          width * (_objectiveProgress / objective.holdSeconds).clamp(0.0, 1.0);
      if (progressWidth > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(center - width / 2, 12, progressWidth, 4),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFC8FFF2),
        );
      }
    }
    if (_objectivePulse > 0) {
      final progress = 1 - _objectivePulse / 1.2;
      canvas.drawCircle(
        Offset(_completedObjectiveCenter, -2),
        18 + progress * 30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF8DFFE3)
              .withValues(alpha: (_objectivePulse / 1.2 * 0.7).clamp(0, 1)),
      );
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
    if (_activeObjective?.objectIndex == index) {
      canvas.drawCircle(
        center,
        radius + 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF99FFE7),
      );
    }
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
    super.onDispose();
  }
}
