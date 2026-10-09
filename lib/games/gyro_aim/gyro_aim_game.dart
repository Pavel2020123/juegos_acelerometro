import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/sensors/gyroscope_service.dart';

enum GyroAimPhase { intro, calibrating, playing, paused, results, error }

enum GyroAimAudioEvent { shot }

class GyroAimTarget {
  const GyroAimTarget({required this.position, required this.radius});

  final Offset position;
  final double radius;
}

/// Game state for Gyro Aim.
///
/// The sensor reports angular velocity, so the aim is moved by integrating
/// angular velocity over a monotonic elapsed interval. It deliberately does
/// not pretend that the gyroscope provides an absolute orientation.
class GyroAimGame extends ChangeNotifier {
  GyroAimGame({GyroscopeService? gyroscopeService, this.onAudioEvent})
    : _gyroscopeService = gyroscopeService ?? GyroscopeService();

  static const double gameDuration = 30;
  static const double defaultSensitivity = 1;
  static const double minSensitivity = 0.4;
  static const double maxSensitivity = 2.4;
  static const double deadZone = 0.04;
  static const double maxSampleDelta = 0.12;

  final GyroscopeService _gyroscopeService;
  final void Function(GyroAimAudioEvent event)? onAudioEvent;
  final Stopwatch _monotonicClock = Stopwatch();
  final math.Random _random = math.Random(73);

  StreamSubscription<GyroscopeReading>? _subscription;
  Size _viewport = Size.zero;
  Offset _aimPosition = Offset.zero;
  GyroAimTarget? _target;
  GyroAimPhase _phase = GyroAimPhase.intro;
  GyroAimPhase? _phaseBeforePause;
  Object? _sensorError;
  bool _sensorAvailable = false;
  bool _receivedReading = false;
  bool _closed = false;
  bool _listening = false;
  int? _lastSampleMicros;
  double _calibrationRemaining = 0;
  double _biasX = 0;
  double _biasY = 0;
  double _biasZ = 0;
  double _calibrationX = 0;
  double _calibrationY = 0;
  double _calibrationZ = 0;
  int _calibrationSamples = 0;
  double _filteredHorizontal = 0;
  double _filteredVertical = 0;
  double _elapsed = 0;
  double _sensitivity = defaultSensitivity;
  int _score = 0;
  int _hits = 0;
  int _shots = 0;
  double _hitFlash = 0;
  double _missFlash = 0;

  GyroAimPhase get phase => _phase;
  Size get viewport => _viewport;
  Offset get aimPosition => _aimPosition;
  GyroAimTarget? get target => _target;
  double get elapsed => _elapsed;
  double get remaining => math.max(0, gameDuration - _elapsed);
  double get sensitivity => _sensitivity;
  int get score => _score;
  int get hits => _hits;
  int get shots => _shots;
  double get accuracy => _shots == 0 ? 0 : _hits / _shots * 100;
  double get hitFlash => _hitFlash;
  double get missFlash => _missFlash;
  bool get sensorAvailable => _sensorAvailable;
  bool get isListening => _listening;
  Object? get sensorError => _sensorError;
  double get calibratedBiasZ => _biasZ;
  bool get isClosed => _closed;

  void setViewport(Size size) {
    if (size.width <= 0 || size.height <= 0 || size == _viewport) return;
    _viewport = size;
    if (_aimPosition == Offset.zero) {
      _aimPosition = _center;
    } else {
      _aimPosition = _clampAim(_aimPosition);
    }
    if (_target != null) _target = _clampTarget(_target!);
  }

  void setSensitivity(double value) {
    final next = value.clamp(minSensitivity, maxSensitivity).toDouble();
    if ((next - _sensitivity).abs() < 0.001) return;
    _sensitivity = next;
    notifyListeners();
  }

  /// Starts a fresh round and performs a short stationary bias calibration.
  void begin() {
    if (_closed) return;
    _resetRound();
    _phase = GyroAimPhase.calibrating;
    _calibrationRemaining = 0.7;
    _monotonicClock
      ..reset()
      ..start();
    _lastSampleMicros = null;
    _ensureListening();
    notifyListeners();
  }

  /// Restarts from the results screen and immediately calibrates again.
  void restart() => begin();

  void pause() {
    if (_closed ||
        (_phase != GyroAimPhase.playing &&
            _phase != GyroAimPhase.calibrating)) {
      return;
    }
    _phaseBeforePause = _phase;
    _phase = GyroAimPhase.paused;
    _monotonicClock.stop();
    _lastSampleMicros = null;
    _filteredHorizontal = 0;
    _filteredVertical = 0;
    notifyListeners();
  }

  void resume() {
    if (_closed || _phase != GyroAimPhase.paused) return;
    _phase = _phaseBeforePause ?? GyroAimPhase.playing;
    _phaseBeforePause = null;
    _lastSampleMicros = null;
    _filteredHorizontal = 0;
    _filteredVertical = 0;
    _monotonicClock.start();
    _ensureListening();
    notifyListeners();
  }

  void centerAim() {
    if (_closed || _viewport == Size.zero) return;
    _aimPosition = _center;
    _filteredHorizontal = 0;
    _filteredVertical = 0;
    _lastSampleMicros = null;
    notifyListeners();
  }

  /// Test hook used by deterministic logic tests to place the crosshair.
  void setAimForTest(Offset position) {
    if (_closed) return;
    _aimPosition = _clampAim(position);
  }

  void fire() {
    if (_closed || _phase != GyroAimPhase.playing || _target == null) return;
    _shots++;
    onAudioEvent?.call(GyroAimAudioEvent.shot);
    if ((_aimPosition - _target!.position).distance <= _target!.radius + 13) {
      _hits++;
      _score += 10;
      _hitFlash = 0.28;
      _spawnTarget();
    } else {
      _missFlash = 0.18;
    }
    notifyListeners();
  }

  /// Applies one sample with a supplied interval. This is also useful for
  /// deterministic unit tests; production samples use the monotonic clock.
  void applyReading(GyroscopeReading reading, {double? elapsedSeconds}) {
    if (_closed) return;
    _sensorAvailable = true;
    _sensorError = null;
    _receivedReading = true;
    if (_phase == GyroAimPhase.calibrating) {
      _calibrationX += reading.x;
      _calibrationY += reading.y;
      _calibrationZ += reading.z;
      _calibrationSamples++;
      notifyListeners();
      return;
    }
    if (_phase != GyroAimPhase.playing) return;

    final now = _monotonicClock.elapsedMicroseconds;
    final rawDelta =
        elapsedSeconds ??
        (_lastSampleMicros == null
            ? 0
            : (now - _lastSampleMicros!) / Duration.microsecondsPerSecond);
    _lastSampleMicros = now;
    final dt = rawDelta.clamp(0.0, maxSampleDelta).toDouble();
    if (dt <= 0) return;
    _integrate(reading, dt);
    notifyListeners();
  }

  /// Exposes the integration step without making tests depend on wall time.
  void integrateForTest(GyroscopeReading reading, double elapsedSeconds) {
    if (_phase == GyroAimPhase.playing) {
      _sensorAvailable = true;
      _receivedReading = true;
      _integrate(reading, elapsedSeconds.clamp(0, maxSampleDelta).toDouble());
      notifyListeners();
    }
  }

  void update(double delta) {
    if (_closed || delta <= 0) return;
    // The screen supplies frame-sized deltas. Direct callers may advance the
    // deterministic model by a larger interval, while sensor samples remain
    // protected by maxSampleDelta in _integrate.
    final dt = delta;
    if (_phase == GyroAimPhase.calibrating) {
      _calibrationRemaining -= dt;
      if (_calibrationRemaining <= 0) _finishCalibration();
      notifyListeners();
      return;
    }
    if (_phase != GyroAimPhase.playing) return;
    _elapsed = math.min(gameDuration, _elapsed + dt);
    _hitFlash = math.max(0, _hitFlash - dt);
    _missFlash = math.max(0, _missFlash - dt);
    if (_elapsed >= gameDuration) _finishRound();
    notifyListeners();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    _listening = false;
    await _gyroscopeService.dispose();
    _monotonicClock.stop();
    super.dispose();
  }

  void _ensureListening() {
    if (_subscription != null || _closed) return;
    _listening = true;
    _subscription = _gyroscopeService.readings.listen(
      applyReading,
      onError: _handleSensorError,
    );
    _gyroscopeService.start();
  }

  void _handleSensorError(Object error, [StackTrace? stackTrace]) {
    if (_closed) return;
    _sensorAvailable = false;
    _sensorError = error;
    if (_phase == GyroAimPhase.calibrating || _phase == GyroAimPhase.playing) {
      _phase = GyroAimPhase.error;
      _monotonicClock.stop();
      unawaited(_stopListening());
    }
    notifyListeners();
  }

  void _finishCalibration() {
    if (!_receivedReading || _calibrationSamples == 0) {
      _sensorError = StateError('No se recibieron lecturas del giroscopio');
      _sensorAvailable = false;
      _phase = GyroAimPhase.error;
      _monotonicClock.stop();
      unawaited(_stopListening());
      return;
    }
    _biasX = _calibrationX / _calibrationSamples;
    _biasY = _calibrationY / _calibrationSamples;
    _biasZ = _calibrationZ / _calibrationSamples;
    _phase = GyroAimPhase.playing;
    _elapsed = 0;
    _lastSampleMicros = null;
    _spawnTarget();
  }

  void _finishRound() {
    if (_phase != GyroAimPhase.playing) return;
    _phase = GyroAimPhase.results;
    _monotonicClock.stop();
    unawaited(_stopListening());
  }

  Future<void> _stopListening() async {
    final subscription = _subscription;
    _subscription = null;
    _listening = false;
    await subscription?.cancel();
    // A restart can create a new listener while the old cancellation is
    // completing. Do not let the old cleanup stop that fresh sensor session.
    if (!_closed && _subscription == null) {
      await _gyroscopeService.stop();
    }
  }

  void _resetRound() {
    _elapsed = 0;
    _score = 0;
    _hits = 0;
    _shots = 0;
    _hitFlash = 0;
    _missFlash = 0;
    _target = null;
    _sensorError = null;
    _sensorAvailable = false;
    _receivedReading = false;
    _calibrationX = 0;
    _calibrationY = 0;
    _calibrationZ = 0;
    _calibrationSamples = 0;
    _biasX = 0;
    _biasY = 0;
    _biasZ = 0;
    if (_viewport != Size.zero) _aimPosition = _center;
  }

  void _integrate(GyroscopeReading reading, double dt) {
    final horizontal = _applyDeadZone(reading.y - _biasY);
    final vertical = _applyDeadZone(reading.x - _biasX);
    _filteredHorizontal = horizontal == 0
        ? 0
        : _filteredHorizontal + (horizontal - _filteredHorizontal) * 0.28;
    _filteredVertical = vertical == 0
        ? 0
        : _filteredVertical + (vertical - _filteredVertical) * 0.28;

    // In portrait orientation y is yaw (horizontal), x is pitch (vertical).
    // The signs are intentionally explicit so they can be inverted after a
    // real-device check without confusing axes or using the accelerometer.
    const horizontalSign = 1.0;
    const verticalSign = -1.0;
    final movement = Offset(
      _filteredHorizontal * horizontalSign * _sensitivity * 180 * dt,
      _filteredVertical * verticalSign * _sensitivity * 180 * dt,
    );
    _aimPosition = _clampAim(_aimPosition + movement);
  }

  double _applyDeadZone(double value) {
    final magnitude = value.abs();
    if (magnitude <= deadZone) return 0;
    return value.sign * (magnitude - deadZone);
  }

  Offset get _center => Offset(_viewport.width / 2, _playTop + _playHeight / 2);

  double get _playTop => math.min(138, _viewport.height * 0.25);

  double get _playBottom => math.max(_playTop + 180, _viewport.height - 118);

  double get _playHeight => math.max(1, _playBottom - _playTop);

  Offset _clampAim(Offset position) => Offset(
    position.dx.clamp(20, math.max(20, _viewport.width - 20)),
    position.dy.clamp(_playTop + 20, math.max(_playTop + 20, _playBottom - 20)),
  );

  GyroAimTarget _clampTarget(GyroAimTarget target) {
    final radius = target.radius;
    return GyroAimTarget(
      radius: radius,
      position: Offset(
        target.position.dx.clamp(
          radius + 8,
          math.max(radius + 8, _viewport.width - radius - 8),
        ),
        target.position.dy.clamp(
          _playTop + radius + 8,
          math.max(_playTop + radius + 8, _playBottom - radius - 8),
        ),
      ),
    );
  }

  void _spawnTarget() {
    if (_viewport == Size.zero) return;
    final radius = (_viewport.shortestSide * 0.075).clamp(25, 34).toDouble();
    final x =
        radius +
        12 +
        _random.nextDouble() * math.max(1, _viewport.width - 2 * (radius + 12));
    final y =
        _playTop +
        radius +
        12 +
        _random.nextDouble() * math.max(1, _playHeight - 2 * (radius + 12));
    _target = GyroAimTarget(position: Offset(x, y), radius: radius);
  }
}
