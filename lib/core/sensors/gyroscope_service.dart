import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

/// A small application-level representation of a gyroscope sample.
/// Values are angular velocity in radians per second.
class GyroscopeReading {
  const GyroscopeReading({
    required this.x,
    required this.y,
    required this.z,
    this.timestamp,
  });

  final double x;
  final double y;
  final double z;
  final DateTime? timestamp;
}

/// Owns the platform gyroscope subscription and exposes a testable stream.
class GyroscopeService {
  GyroscopeService({this._samplingPeriod = SensorInterval.normalInterval});

  final Duration _samplingPeriod;
  final StreamController<GyroscopeReading> _controller =
      StreamController<GyroscopeReading>.broadcast();

  StreamSubscription<GyroscopeEvent>? _subscription;
  bool _disposed = false;

  Stream<GyroscopeReading> get readings => _controller.stream;
  bool get isStarted => _subscription != null;

  void start() {
    if (_disposed || _subscription != null) return;
    try {
      _subscription = gyroscopeEventStream(samplingPeriod: _samplingPeriod)
          .listen(
            (event) => _controller.add(
              GyroscopeReading(
                x: event.x,
                y: event.y,
                z: event.z,
                timestamp: event.timestamp,
              ),
            ),
            onError: _controller.addError,
          );
    } catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _controller.close();
  }
}
