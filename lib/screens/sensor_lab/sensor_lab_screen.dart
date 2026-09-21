import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sensors/accelerometer_service.dart';

class SensorLabScreen extends StatefulWidget {
  const SensorLabScreen({super.key});

  @override
  State<SensorLabScreen> createState() => _SensorLabScreenState();
}

class _SensorLabScreenState extends State<SensorLabScreen> {
  final AccelerometerService _accelerometerService = AccelerometerService();

  StreamSubscription<AccelerometerReading>? _readingsSubscription;
  AccelerometerReading _reading = const AccelerometerReading(
    x: 0,
    y: 0,
    z: 0,
    magnitude: 0,
  );

  @override
  void initState() {
    super.initState();
    _readingsSubscription = _accelerometerService.readings.listen((reading) {
      if (mounted) {
        setState(() => _reading = reading);
      }
    });
    _accelerometerService.start();
  }

  @override
  void dispose() {
    unawaited(_readingsSubscription?.cancel());
    unawaited(_accelerometerService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Lab')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACCELLAB', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Sensor Lab', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 32),
            const Text('Estado:'),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.circle, color: Colors.green, size: 12),
                SizedBox(width: 8),
                Text('Acelerómetro activo'),
              ],
            ),
            const SizedBox(height: 32),
            _AxisReading(label: 'X', value: _reading.x),
            _AxisReading(label: 'Y', value: _reading.y),
            _AxisReading(label: 'Z', value: _reading.z),
            const SizedBox(height: 24),
            Text('Magnitud:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${_reading.magnitude.toStringAsFixed(2)} m/s²',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisReading extends StatelessWidget {
  const _AxisReading({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final progress = (value.abs() / 10).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
          SizedBox(
            width: 72,
            child: Text(value.toStringAsFixed(2), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
