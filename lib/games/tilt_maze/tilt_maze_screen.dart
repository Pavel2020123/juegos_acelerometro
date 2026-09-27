import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'tilt_maze_level.dart';
import '../../core/audio/audio_service.dart';
import '../../core/sensors/accelerometer_service.dart';
import '../../core/theme/app_theme.dart';
import 'tilt_maze_game.dart';

class TiltMazeScreen extends StatefulWidget {
  const TiltMazeScreen({
    required this.level,
    this.accelerometerService,
    super.key,
  });

  final TiltMazeLevel level;
  final AccelerometerService? accelerometerService;

  @override
  State<TiltMazeScreen> createState() => _TiltMazeScreenState();
}

class _TiltMazeScreenState extends State<TiltMazeScreen>
    with WidgetsBindingObserver {
  late final TiltMazeGame _game;
  bool _paused = false;
  bool _touchMode = false;
  double _sensitivity = 1;

  void _setPaused(bool value) {
    setState(() => _paused = value);
    if (value) {
      _game.pausePlay();
      AppAudio.instance.setGamePaused(true);
    } else {
      _game.resumePlay();
      AppAudio.instance.setGamePaused(false);
    }
  }

  void _setTouchMode(bool value) {
    setState(() => _touchMode = value);
    _game.setTouchMode(value);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _game = TiltMazeGame(
      level: widget.level,
      accelerometerService: widget.accelerometerService,
      onAudioEvent: (event) {
        switch (event) {
          case TiltMazeAudioEvent.ice:
            AppAudio.instance.play(AppSound.ice);
          case TiltMazeAudioEvent.laser:
            AppAudio.instance.play(AppSound.laser);
          case TiltMazeAudioEvent.checkpoint:
            AppAudio.instance.play(AppSound.checkpoint);
          case TiltMazeAudioEvent.respawn:
            AppAudio.instance.play(AppSound.respawn);
          case TiltMazeAudioEvent.victory:
            AppAudio.instance.play(AppSound.victory);
        }
      },
    );
    AppAudio.instance.claimSilence(this);
  }

  @override
  void dispose() {
    AppAudio.instance.releaseMusic(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_game.close());

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_paused) {
      _setPaused(true);
    }
  }

  void _moveTouch(Offset position) {
    final x = ((position.dx - 65) / 50).clamp(-1.0, 1.0);
    final y = ((position.dy - 65) / 50).clamp(-1.0, 1.0);
    _game.touchInput = Vector2(x, y);
  }

  String _formatTime(double seconds) {
    final minutes = seconds ~/ 60;

    final remaining = seconds % 60;

    return '$minutes:${remaining.toStringAsFixed(1).padLeft(4, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      body: Stack(
        children: [
          // =========================
          // JUEGO
          // =========================

          GameWidget(game: _game),

          Positioned(
            top: 110,
            left: 16,
            right: 16,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xEFFFFFFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2220334D),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Volver a niveles',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: _paused ? 'Continuar' : 'Pausar',
                        onPressed: () => _setPaused(!_paused),
                        icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        tooltip: 'Calibrar posición actual',
                        onPressed: () {
                          final calibrated = _game.calibrate();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                calibrated ? 'Posición calibrada' : 'Activa el control táctil si no hay sensor',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.tune),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: _touchMode
                            ? 'Usar acelerómetro'
                            : 'Usar control táctil',
                        onPressed: () => _setTouchMode(!_touchMode),
                        icon: Icon(
                          _touchMode ? Icons.screen_rotation : Icons.touch_app,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_touchMode && !_paused)
            Positioned(
              bottom: 28,
              left: 22,
              child: SafeArea(
                child: GestureDetector(
                  onPanDown: (details) => _moveTouch(details.localPosition),
                  onPanUpdate: (details) => _moveTouch(details.localPosition),
                  onPanEnd: (_) => _game.touchInput = Vector2.zero(),
                  onPanCancel: () => _game.touchInput = Vector2.zero(),
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xDFFFFFFF),
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: const Icon(
                      Icons.control_camera,
                      color: AppColors.tiltMaze,
                      size: 45,
                    ),
                  ),
                ),
              ),
            ),

          if (!_touchMode)
            Positioned(
              bottom: 18,
              right: 16,
              child: SafeArea(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _game.sensorAvailable,
                  builder: (_, available, _) => available
                      ? const SizedBox.shrink()
                      : const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xF7FFFFFF),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            border: Border.fromBorderSide(
                              BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              'Sin sensor: usa el control táctil',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                ),
              ),
            ),

          if (_paused)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x99F6F8FC),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2220334D),
                          blurRadius: 22,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'PAUSA',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sensibilidad: ${_sensitivity.toStringAsFixed(1)}×',
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        SizedBox(
                          width: 260,
                          child: Slider(
                            value: _sensitivity,
                            min: 0.5,
                            max: 1.5,
                            divisions: 10,
                            onChanged: (value) {
                              setState(() => _sensitivity = value);
                              _game.sensitivity = value;
                            },
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _setPaused(false),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('CONTINUAR'),
                        ),
                        TextButton(
                          onPressed: () {
                            _game.restartLevel();
                            _setPaused(false);
                          },
                          child: const Text('REINICIAR NIVEL'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // =========================
          // HUD
          // =========================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          title: 'TILT MAZE',
                          value:
                              'NIVEL ${widget.level.id.toString().padLeft(2, '0')}',
                        ),
                      ),

                      const SizedBox(width: 10),

                      ValueListenableBuilder<TiltMazeHudState>(
                        valueListenable: _game.hud,
                        builder: (context, hud, child) {
                          return _buildInfoCard(
                            title: 'TIEMPO',
                            value: _formatTime(hud.time),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  ValueListenableBuilder<TiltMazeHudState>(
                    valueListenable: _game.hud,
                    builder: (context, hud, child) {
                      return Row(
                        children: [
                          Icon(Icons.flag, size: 18, color: AppColors.tiltMaze),

                          const SizedBox(width: 6),

                          Text(
                            'Checkpoint '
                            '${hud.checkpoint}'
                            '/'
                            '${hud.totalCheckpoints}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const Spacer(),

                          ValueListenableBuilder<AccelerometerReading>(
                            valueListenable: _game.currentReading,
                            builder: (context, reading, child) {
                              return Text(
                                'X ${reading.x.toStringAsFixed(1)}  '
                                'Y ${reading.y.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
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
          ValueListenableBuilder<TiltMazeHudState>(
            valueListenable: _game.hud,
            builder: (context, hud, child) {
              if (!hud.falling) {
                return const SizedBox.shrink();
              }

              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xF7FFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    '¡CAÍSTE!',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),

          // =========================
          // NIVEL COMPLETADO
          // =========================
          ValueListenableBuilder<TiltMazeHudState>(
            valueListenable: _game.hud,
            builder: (context, hud, child) {
              if (!hud.completed) {
                return const SizedBox.shrink();
              }

              return Container(
                color: const Color(0x99F6F8FC),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(28),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 390),
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2220334D),
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 72,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        widget.level.id == tiltMazeLevels.last.id
                            ? '¡COMPLETASTE TILT MAZE!'
                            : '¡NIVEL COMPLETADO!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Tiempo: '
                        '${_formatTime(hud.time)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 26),

                      SizedBox(
                        width: 210,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () {
                            _game.restartLevel();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('JUGAR DE NUEVO'),
                        ),
                      ),
                      if (widget.level.id < tiltMazeLevels.length) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TiltMazeScreen(
                                  level: tiltMazeLevels[widget.level.id],
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('SIGUIENTE NIVEL'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A20334D),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: title == 'TILT MAZE'
                  ? AppColors.tiltMaze
                  : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: title == 'TILT MAZE'
                  ? AppColors.tiltMaze
                  : AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
