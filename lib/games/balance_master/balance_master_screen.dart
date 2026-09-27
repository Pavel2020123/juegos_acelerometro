import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/sensors/accelerometer_service.dart';
import '../../core/audio/audio_service.dart';
import '../../core/theme/app_theme.dart';
import 'balance_master_game.dart';
import 'balance_master_level.dart';

class BalanceMasterScreen extends StatefulWidget {
  const BalanceMasterScreen({
    required this.level,
    this.accelerometerService,
    super.key,
  });

  final BalanceMasterLevel level;
  final AccelerometerService? accelerometerService;

  @override
  State<BalanceMasterScreen> createState() => _BalanceMasterScreenState();
}

class _BalanceMasterScreenState extends State<BalanceMasterScreen>
    with WidgetsBindingObserver {
  late final BalanceMasterGame _game;
  bool _paused = false;
  bool _touchMode = false;
  double _touchTilt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppAudio.instance.claimSilence(this);
    _game = BalanceMasterGame(
      level: widget.level,
      accelerometerService: widget.accelerometerService,
    );
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

  void _setPaused(bool value) {
    setState(() => _paused = value);
    if (value) {
      _touchTilt = 0;
      _game.pausePlay();
    } else {
      _game.resumePlay();
    }
  }

  void _setTouchMode(bool value) {
    setState(() {
      _touchMode = value;
      _touchTilt = 0;
    });
    _game.setTouchMode(value);
  }

  void _calibrate() {
    if (_game.calibrate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esperando acelerómetro. Puedes usar CONTROL TÁCTIL.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _time(double seconds) => seconds.toStringAsFixed(1);

  String _points(int points) {
    final digits = points.toString();
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      groups.insert(0, digits.substring((end - 3).clamp(0, end), end));
    }
    return groups.join(' ');
  }

  String _objectiveLabel(int index) {
    if (widget.level.objectCount == 1) {
      return 'OBJETIVO · MANTÉN LA ESFERA EN LA ZONA';
    }
    final objectName = switch (index) {
      0 => 'VIOLETA',
      1 => 'CELESTE',
      _ => 'VERDE',
    };
    return 'OBJETIVO · LLEVA EL OBJETO $objectName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      body: Stack(
        children: [
          GameWidget(game: _game),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ValueListenableBuilder<BalanceHudState>(
                valueListenable: _game.hud,
                builder: (_, hud, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Volver a niveles',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _card(
                            'BALANCE MASTER',
                            'NIVEL ${widget.level.id.toString().padLeft(2, '0')}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: _touchMode
                              ? 'CONTROL: TÁCTIL'
                              : 'CONTROL: SENSOR',
                          onPressed: () => _setTouchMode(!_touchMode),
                          icon: Icon(
                            _touchMode
                                ? Icons.touch_app
                                : Icons.screen_rotation,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Pausar',
                          onPressed: _paused ? null : () => _setPaused(true),
                          icon: const Icon(Icons.pause),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _card(
                            'TIEMPO',
                            '${_time(hud.elapsed)} / ${widget.level.duration.toInt()} s',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _card(
                            'ESTABILIDAD',
                            '${hud.stability.round()}%',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: hud.stability >= 85
                            ? const [
                                BoxShadow(
                                  color: Color(0x5547D9CC),
                                  blurRadius: 9,
                                ),
                              ]
                            : const [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: hud.stability / 100,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFE1EAF2),
                          color: hud.stability < 45
                              ? const Color(0xFFE4775D)
                              : AppColors.balanceMaster,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'PUNTOS ${_points(hud.score)}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (hud.combo > 1)
                          Text(
                            'COMBO x${hud.combo}',
                            style: const TextStyle(
                              color: AppColors.balanceMaster,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    if (hud.objectiveIndex != null &&
                        hud.phase == BalancePhase.playing) ...[
                      const SizedBox(height: 8),
                      Text(
                        _objectiveLabel(hud.objectiveIndex!),
                        style: const TextStyle(
                          color: AppColors.balanceMaster,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: hud.objectiveProgress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFDCEAF0),
                          color: AppColors.balanceMaster,
                        ),
                      ),
                    ] else if (hud.objectiveCompletedPulse &&
                        hud.phase == BalancePhase.playing)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '✓ OBJETIVO COMPLETADO',
                          style: TextStyle(
                            color: AppColors.balanceMaster,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!_paused)
            ValueListenableBuilder<BalanceHudState>(
              valueListenable: _game.hud,
              builder: (_, hud, _) => hud.impulseWarning || hud.platformWarning
                  ? Align(
                      alignment: const Alignment(0, -0.18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: _panelDecoration,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hud.impulseWarning
                                  ? hud.gustFromLeft
                                        ? '→'
                                        : '←'
                                  : '↔',
                              style: const TextStyle(
                                color: Color(0xFFAD6700),
                                fontSize: 38,
                                height: 1,
                              ),
                            ),
                            Text(
                              hud.impulseWarning
                                  ? '⚠ RÁFAGA DESDE LA ${hud.gustFromLeft ? 'IZQUIERDA' : 'DERECHA'}'
                                  : '⚠ PLATAFORMA INESTABLE',
                              style: const TextStyle(
                                color: Color(0xFFAD6700),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          if (!_paused)
            ValueListenableBuilder<BalanceHudState>(
              valueListenable: _game.hud,
              builder: (_, hud, _) => switch (hud.phase) {
                BalancePhase.calibrating => _calibrationOverlay(),
                BalancePhase.countdown => _countdownOverlay(hud.countdown),
                BalancePhase.lost => _resultOverlay(hud, won: false),
                BalancePhase.won => _resultOverlay(hud, won: true),
                _ => const SizedBox.shrink(),
              },
            ),
          if (!_paused && _touchMode)
            ValueListenableBuilder<BalanceHudState>(
              valueListenable: _game.hud,
              builder: (_, hud, _) => hud.phase == BalancePhase.playing
                  ? Positioned(
                      left: 22,
                      right: 22,
                      bottom: 18,
                      child: SafeArea(child: _touchControl()),
                    )
                  : const SizedBox.shrink(),
            ),
          if (!_paused && !_touchMode)
            Positioned(
              right: 16,
              bottom: 18,
              child: SafeArea(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _game.sensorAvailable,
                  builder: (_, available, _) => available
                      ? const SizedBox.shrink()
                      : const Text(
                          'Sin sensor: activa CONTROL TÁCTIL',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                ),
              ),
            ),
          if (_paused) _pauseOverlay(),
        ],
      ),
    );
  }

  Widget _card(String title, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xEFFFFFFF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _calibrationOverlay() => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.balance, size: 56, color: AppColors.balanceMaster),
          const SizedBox(height: 12),
          const Text(
            'ENCUENTRA TU CENTRO',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Mantén el teléfono cómodo y estable.\n'
            'Esa posición será el punto neutral.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _calibrate,
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('CALIBRAR'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _setTouchMode(!_touchMode),
            child: Text(_touchMode ? 'CONTROL: TÁCTIL' : 'CONTROL: SENSOR'),
          ),
        ],
      ),
    ),
  );

  Widget _countdownOverlay(double remaining) => Center(
    child: Text(
      remaining > 0.6 ? '${remaining.ceil() - 1}' : '¡EQUILIBRA!',
      style: const TextStyle(
        color: AppColors.balanceMaster,
        fontSize: 46,
        fontWeight: FontWeight.w900,
        shadows: [Shadow(color: AppColors.balanceMaster, blurRadius: 14)],
      ),
    ),
  );

  Widget _touchControl() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    decoration: _panelDecoration,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'CONTROL: TÁCTIL  ·  DESLIZA SUAVEMENTE',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        Slider(
          value: _touchTilt,
          min: -1,
          max: 1,
          onChanged: (value) {
            setState(() => _touchTilt = value);
            _game.setTouchTilt(value);
          },
          onChangeEnd: (_) {
            setState(() => _touchTilt = 0);
            _game.setTouchTilt(0);
          },
        ),
      ],
    ),
  );

  Widget _pauseOverlay() => Positioned.fill(
    child: ColoredBox(
      color: const Color(0x99F6F8FC),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: _panelDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PAUSA',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _setPaused(false),
                icon: const Icon(Icons.play_arrow),
                label: const Text('CONTINUAR'),
              ),
              TextButton(
                onPressed: () {
                  _game.restart();
                  _setPaused(false);
                },
                child: const Text('REINICIAR NIVEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('VOLVER A NIVELES'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _resultOverlay(
    BalanceHudState hud, {
    required bool won,
  }) => Positioned.fill(
    child: ColoredBox(
      color: const Color(0x99F6F8FC),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: _panelDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  won ? Icons.emoji_events : Icons.south,
                  color: won
                      ? AppColors.balanceMaster
                      : const Color(0xFFE4775D),
                  size: 64,
                ),
                const SizedBox(height: 14),
                Text(
                  won
                      ? widget.level.id == balanceMasterLevels.last.id
                            ? '¡BALANCE MASTER COMPLETADO!'
                            : '¡EQUILIBRIO PERFECTO!'
                      : '¡PERDISTE EL EQUILIBRIO!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Nivel ${widget.level.id}  ·  ${_time(hud.elapsed)} s',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (won)
                  Text(
                    'Estabilidad promedio: ${hud.averageStability.round()}%',
                    style: const TextStyle(color: AppColors.balanceMaster),
                  ),
                if (won) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${'★' * hud.stars}${'☆' * (3 - hud.stars)}',
                    style: const TextStyle(
                      color: Color(0xFFD99A21),
                      fontSize: 34,
                      letterSpacing: 5,
                    ),
                  ),
                  Text(
                    'Objetivos: ${hud.objectivesCompleted}/${hud.totalObjectives}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    'Combo máximo: x${hud.maxCombo}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                Text(
                  'Puntos: ${_points(hud.score)}',
                  style: const TextStyle(
                    color: AppColors.balanceMaster,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _game.restart,
                  icon: const Icon(Icons.refresh),
                  label: Text(won ? 'JUGAR DE NUEVO' : 'REINTENTAR'),
                ),
                if (won && widget.level.id < balanceMasterLevels.length)
                  TextButton.icon(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BalanceMasterScreen(
                          level: balanceMasterLevels[widget.level.id],
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('SIGUIENTE NIVEL'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('VOLVER A NIVELES'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  BoxDecoration get _panelDecoration => BoxDecoration(
    color: const Color(0xF7FFFFFF),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(color: Color(0x2220334D), blurRadius: 22, offset: Offset(0, 8)),
    ],
  );
}
