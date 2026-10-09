import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_logo.dart';
import '../../core/sensors/accelerometer_service.dart';
import '../../core/sensors/gyroscope_service.dart';
import '../../core/theme/app_theme.dart';

class SensorLabScreen extends StatefulWidget {
  const SensorLabScreen({super.key});

  @override
  State<SensorLabScreen> createState() => _SensorLabScreenState();
}

class _SensorLabScreenState extends State<SensorLabScreen> {
  final AccelerometerService _accelerometerService = AccelerometerService();
  final GyroscopeService _gyroscopeService = GyroscopeService();

  StreamSubscription<AccelerometerReading>? _accelerometerSubscription;
  StreamSubscription<GyroscopeReading>? _gyroscopeSubscription;
  AccelerometerReading _accelerometer = const AccelerometerReading(
    x: 0,
    y: 0,
    z: 0,
    magnitude: 0,
  );
  GyroscopeReading _gyroscope = const GyroscopeReading(x: 0, y: 0, z: 0);
  Object? _accelerometerError;
  Object? _gyroscopeError;
  bool _gotAccelerometerReading = false;
  bool _gotGyroscopeReading = false;

  @override
  void initState() {
    super.initState();
    _accelerometerSubscription = _accelerometerService.readings.listen(
      (reading) {
        if (!mounted) return;
        setState(() {
          _accelerometer = reading;
          _gotAccelerometerReading = true;
          _accelerometerError = null;
        });
      },
      onError: (Object error) {
        if (mounted) setState(() => _accelerometerError = error);
      },
    );
    _gyroscopeSubscription = _gyroscopeService.readings.listen(
      (reading) {
        if (!mounted) return;
        setState(() {
          _gyroscope = reading;
          _gotGyroscopeReading = true;
          _gyroscopeError = null;
        });
      },
      onError: (Object error) {
        if (mounted) setState(() => _gyroscopeError = error);
      },
    );
    _accelerometerService.start();
    _gyroscopeService.start();
  }

  @override
  void dispose() {
    unawaited(_accelerometerSubscription?.cancel());
    unawaited(_gyroscopeSubscription?.cancel());
    unawaited(_accelerometerService.dispose());
    unawaited(_gyroscopeService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laboratorio de sensores'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: AppLogo(size: 32),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text('ACCELLAB', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text('Observa lecturas reales en tiempo real.'),
          const SizedBox(height: 20),
          _SensorCard(
            title: 'ACELERÓMETRO',
            subtitle: 'Aceleración lineal y gravedad',
            unit: 'm/s²',
            color: AppColors.tiltMaze,
            available: _gotAccelerometerReading,
            error: _accelerometerError,
            values: [_accelerometer.x, _accelerometer.y, _accelerometer.z],
          ),
          const SizedBox(height: 14),
          _SensorCard(
            title: 'GIROSCOPIO',
            subtitle: 'Velocidad angular alrededor de X, Y y Z',
            unit: 'rad/s',
            color: const Color(0xFF0891B2),
            available: _gotGyroscopeReading,
            error: _gyroscopeError,
            values: [_gyroscope.x, _gyroscope.y, _gyroscope.z],
          ),
          const SizedBox(height: 18),
          const Text(
            'Los valores del giroscopio representan velocidad angular, no un ángulo absoluto. Gyro Aim integra estas lecturas durante el tiempo para mover la mira.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.color,
    required this.available,
    required this.error,
    required this.values,
  });

  final String title;
  final String subtitle;
  final String unit;
  final Color color;
  final bool available;
  final Object? error;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final state = error != null
        ? 'Error de lectura'
        : available
        ? 'Activo'
        : 'Esperando lecturas';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors_rounded, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                state,
                style: TextStyle(
                  color: error != null ? Colors.red : color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          for (var index = 0; index < values.length; index++)
            _AxisReading(
              label: String.fromCharCode(88 + index),
              value: values[index],
              color: color,
              unit: unit,
            ),
        ],
      ),
    );
  }
}

class _AxisReading extends StatelessWidget {
  const _AxisReading({
    required this.label,
    required this.value,
    required this.color,
    required this.unit,
  });

  final String label;
  final double value;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final progress = (value.abs() / (unit == 'rad/s' ? 4 : 10)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          SizedBox(
            width: 27,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: .1),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              '${value.toStringAsFixed(2)} $unit',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
