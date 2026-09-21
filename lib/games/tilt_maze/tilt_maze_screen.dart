import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/sensors/accelerometer_service.dart';
import 'tilt_maze_game.dart';

class TiltMazeScreen extends StatefulWidget {
  const TiltMazeScreen({super.key});

  @override
  State<TiltMazeScreen> createState() => _TiltMazeScreenState();
}

class _TiltMazeScreenState extends State<TiltMazeScreen> {
  late final TiltMazeGame _game;

  @override
  void initState() {
    super.initState();
    _game = TiltMazeGame();
  }

  @override
  void dispose() {
    unawaited(_game.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TILT MAZE — PROTOTIPO',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Inclina el teléfono para mover la esfera',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<AccelerometerReading>(
                    valueListenable: _game.currentReading,
                    builder: (context, reading, child) {
                      return Text(
                        'X: ${reading.x.toStringAsFixed(2)}\n'
                        'Y: ${reading.y.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
