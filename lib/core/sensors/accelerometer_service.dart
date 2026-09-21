import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

class AccelerometerReading {
  const AccelerometerReading({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
  });

  final double x;
  final double y;
  final double z;
  final double magnitude;
}

class AccelerometerService {
  final StreamController<AccelerometerReading> _controller =
      StreamController<AccelerometerReading>.broadcast();

  StreamSubscription<AccelerometerEvent>? _subscription;
  bool _isDisposed = false;

  Stream<AccelerometerReading> get readings => _controller.stream;

  void start() {
    if (_subscription != null || _isDisposed) {
      return;
    }

    _subscription = accelerometerEventStream().listen((event) {
      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      _controller.add(
        AccelerometerReading(
          x: event.x,
          y: event.y,
          z: event.z,
          magnitude: magnitude,
        ),
      );
    }, onError: _controller.addError);
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
