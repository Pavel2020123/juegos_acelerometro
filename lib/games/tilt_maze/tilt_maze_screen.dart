import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'tilt_maze_level.dart';
import '../../core/sensors/accelerometer_service.dart';
import 'tilt_maze_game.dart';

class TiltMazeScreen extends StatefulWidget {
  const TiltMazeScreen({
    required this.level,
    super.key,
  });

  final TiltMazeLevel level;

  @override
  State<TiltMazeScreen> createState() =>
      _TiltMazeScreenState();
}

class _TiltMazeScreenState
    extends State<TiltMazeScreen> {
  late final TiltMazeGame _game;

  @override
  void initState() {
    super.initState();

    _game = TiltMazeGame(
      level: widget.level,
    );
  }

  @override
  void dispose() {
    unawaited(
      _game.close(),
    );

    super.dispose();
  }

  String _formatTime(
    double seconds,
  ) {
    final minutes =
        seconds ~/ 60;

    final remaining =
        seconds % 60;

    return '$minutes:${remaining.toStringAsFixed(1).padLeft(4, '0')}';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF080C16),
      body: Stack(
        children: [
          // =========================
          // JUEGO
          // =========================

          GameWidget(
            game: _game,
          ),

          // =========================
          // HUD
          // =========================

          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            _buildInfoCard(
                          title:
                              'TILT MAZE',
                          value:
                                'NIVEL ${widget.level.id.toString().padLeft(2, '0')}',
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      ValueListenableBuilder<
                          TiltMazeHudState>(
                        valueListenable:
                            _game.hud,
                        builder: (
                          context,
                          hud,
                          child,
                        ) {
                          return _buildInfoCard(
                            title:
                                'TIEMPO',
                            value:
                                _formatTime(
                              hud.time,
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  ValueListenableBuilder<
                      TiltMazeHudState>(
                    valueListenable:
                        _game.hud,
                    builder: (
                      context,
                      hud,
                      child,
                    ) {
                      return Row(
                        children: [
                          Icon(
                            Icons.flag,
                            size: 18,
                            color:
                                Colors.amber,
                          ),

                          const SizedBox(
                            width: 6,
                          ),

                          Text(
                            'Checkpoint '
                            '${hud.checkpoint}'
                            '/'
                            '${hud.totalCheckpoints}',
                            style:
                                const TextStyle(
                              color:
                                  Colors.white70,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          const Spacer(),

                          ValueListenableBuilder<
                              AccelerometerReading>(
                            valueListenable:
                                _game
                                    .currentReading,
                            builder: (
                              context,
                              reading,
                              child,
                            ) {
                              return Text(
                                'X ${reading.x.toStringAsFixed(1)}  '
                                'Y ${reading.y.toStringAsFixed(1)}',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white38,
                                  fontSize:
                                      11,
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // =========================
          // MENSAJE DE CAÍDA
          // =========================

          ValueListenableBuilder<
              TiltMazeHudState>(
            valueListenable:
                _game.hud,
            builder: (
              context,
              hud,
              child,
            ) {
              if (!hud.falling) {
                return const SizedBox
                    .shrink();
              }

              return Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.black87,
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),
                  child:
                      const Text(
                    '¡CAÍSTE!',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),

          // =========================
          // NIVEL COMPLETADO
          // =========================

          ValueListenableBuilder<
              TiltMazeHudState>(
            valueListenable:
                _game.hud,
            builder: (
              context,
              hud,
              child,
            ) {
              if (!hud.completed) {
                return const SizedBox
                    .shrink();
              }

              return Container(
                color:
                    Colors.black.withValues(
                  alpha: 0.78,
                ),
                alignment:
                    Alignment.center,
                padding:
                    const EdgeInsets.all(
                  28,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color:
                          Colors.amber,
                      size: 72,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    const Text(
                      '¡NIVEL COMPLETADO!',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            27,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Text(
                      'Tiempo: '
                      '${_formatTime(hud.time)}',
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize:
                            18,
                      ),
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    SizedBox(
                      width: 210,
                      height: 52,
                      child:
                          FilledButton.icon(
                        onPressed: () {
                          _game
                              .restartLevel();
                        },
                        icon:
                            const Icon(
                          Icons.refresh,
                        ),
                        label:
                            const Text(
                          'JUGAR DE NUEVO',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFF121A2A)
                .withValues(
          alpha: 0.92,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color:
              Colors.white.withValues(
            alpha: 0.08,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                const TextStyle(
              color:
                  Colors.white38,
              fontSize:
                  10,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            value,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize:
                  16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}