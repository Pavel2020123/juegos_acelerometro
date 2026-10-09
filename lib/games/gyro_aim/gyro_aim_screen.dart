import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app_logo.dart';
import '../../core/audio/audio_service.dart';
import '../../core/sensors/gyroscope_service.dart';
import 'gyro_aim_game.dart';

class GyroAimScreen extends StatefulWidget {
  const GyroAimScreen({this.gyroscopeService, super.key});

  final GyroscopeService? gyroscopeService;

  @override
  State<GyroAimScreen> createState() => _GyroAimScreenState();
}

class _GyroAimScreenState extends State<GyroAimScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final GyroAimGame _game;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = GyroAimGame(
      gyroscopeService: widget.gyroscopeService,
      onAudioEvent: (event) {
        switch (event) {
          case GyroAimAudioEvent.shot:
            AppAudio.instance.play(AppSound.mainShot);
        }
      },
    );
    AppAudio.instance.claimSilence(this);
    _ticker = createTicker((elapsed) {
      final delta = _lastTick == Duration.zero
          ? 0.0
          : (elapsed - _lastTick).inMicroseconds /
                Duration.microsecondsPerSecond;
      _lastTick = elapsed;
      final previousPhase = _game.phase;
      _game.update(delta.clamp(0.0, 0.1));
      if ((_game.phase == GyroAimPhase.results ||
              _game.phase == GyroAimPhase.error) &&
          _game.phase != previousPhase) {
        AppAudio.instance.setGamePaused(true);
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    AppAudio.instance.releaseMusic(this);
    unawaited(_game.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_game.phase == GyroAimPhase.playing ||
            _game.phase == GyroAimPhase.calibrating)) {
      _game.pause();
      AppAudio.instance.setGamePaused(true);
    }
  }

  void _begin() {
    _lastTick = Duration.zero;
    _game.begin();
    AppAudio.instance.claimMusic(this, AppAudio.astroTrack(1));
    AppAudio.instance.setGamePaused(false);
  }

  void _resume() {
    _game.resume();
    AppAudio.instance.setGamePaused(false);
  }

  void _pause() {
    _game.pause();
    if (_game.phase == GyroAimPhase.paused) {
      AppAudio.instance.setGamePaused(true);
    }
  }

  void _backToCatalog() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1428),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _game.setViewport(constraints.biggest);
          return AnimatedBuilder(
            animation: _game,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _GyroAimPainter(_game)),
                SafeArea(child: _buildInterface()),
                if (_game.phase == GyroAimPhase.intro) _buildIntro(),
                if (_game.phase == GyroAimPhase.calibrating)
                  _buildCalibration(),
                if (_game.phase == GyroAimPhase.paused) _buildPaused(),
                if (_game.phase == GyroAimPhase.results) _buildResults(),
                if (_game.phase == GyroAimPhase.error) _buildError(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInterface() {
    final active = _game.phase == GyroAimPhase.playing;
    return Stack(
      children: [
        Positioned(
          top: 10,
          left: 14,
          right: 14,
          child: Row(
            children: [
              _smallButton(Icons.arrow_back_rounded, 'Volver', _backToCatalog),
              const SizedBox(width: 8),
              const AppLogo(size: 34),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'GYRO AIM',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 17,
                  ),
                ),
              ),
              if (active) ...[
                _smallButton(
                  Icons.center_focus_strong,
                  'Centrar mira',
                  _game.centerAim,
                ),
                const SizedBox(width: 5),
                _smallButton(Icons.pause_rounded, 'Pausar', _pause),
              ],
            ],
          ),
        ),
        if (active ||
            _game.phase == GyroAimPhase.calibrating ||
            _game.phase == GyroAimPhase.paused)
          Positioned(
            top: 67,
            left: 18,
            right: 18,
            child: Row(
              children: [
                _infoPill('TIEMPO', '${_game.remaining.ceil()} s'),
                const SizedBox(width: 7),
                _infoPill('PUNTOS', '${_game.score}'),
                const SizedBox(width: 7),
                _infoPill('PRECISIÓN', '${_game.accuracy.toStringAsFixed(0)}%'),
              ],
            ),
          ),
        if (active)
          Positioned(
            left: 28,
            right: 28,
            bottom: 14,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, size: 15, color: Color(0xFFB8C8E8)),
                    const SizedBox(width: 5),
                    const Text(
                      'SENSIBILIDAD',
                      style: TextStyle(
                        color: Color(0xFFB8C8E8),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _game.sensitivity,
                        min: GyroAimGame.minSensitivity,
                        max: GyroAimGame.maxSensitivity,
                        onChanged: _game.setSensitivity,
                        activeColor: const Color(0xFF5BE7FF),
                        inactiveColor: const Color(0x446F87AC),
                      ),
                    ),
                    Text(
                      _game.sensitivity.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  height: 68,
                  child: FilledButton.icon(
                    onPressed: _game.fire,
                    icon: const Icon(Icons.gps_fixed_rounded, size: 25),
                    label: const Text(
                      'DISPARAR',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF087FBA),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _smallButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          color: Colors.white,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xC51C3151),
            side: const BorderSide(color: Color(0x556E91B9)),
          ),
        ),
      );

  Widget _infoPill(String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xB91A2B48),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x445F83B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CB5D9),
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _overlay({required Widget child}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 410),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xF2182944),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x5579B6DD)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 26,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );

  Widget _buildIntro() => _overlay(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.screen_rotation_alt_rounded,
          color: Color(0xFF5BE7FF),
          size: 54,
        ),
        const SizedBox(height: 10),
        const Text(
          'GYRO AIM',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Apunta girando tu celular.',
          style: TextStyle(
            color: Color(0xFF8FEAFF),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Mantén el teléfono vertical. Gíralo para mover la mira y pulsa DISPARAR cuando esté sobre el objetivo. Consigue la mayor puntuación en 30 segundos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFD3E1F5), height: 1.45),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _begin,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('INICIAR PARTIDA'),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(onPressed: _backToCatalog, child: const Text('VOLVER')),
      ],
    ),
  );

  Widget _buildCalibration() => _overlay(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.sensors_rounded, color: Color(0xFF5BE7FF), size: 46),
        const SizedBox(height: 12),
        const Text(
          'CALIBRANDO GIROSCOPIO',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Deja el celular quieto un momento.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFD3E1F5)),
        ),
        const SizedBox(height: 16),
        const CircularProgressIndicator(color: Color(0xFF5BE7FF)),
      ],
    ),
  );

  Widget _buildPaused() => _overlay(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.pause_circle_outline_rounded,
          color: Color(0xFF5BE7FF),
          size: 52,
        ),
        const SizedBox(height: 8),
        const Text(
          'PARTIDA EN PAUSA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _resume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('CONTINUAR'),
          ),
        ),
        const SizedBox(height: 5),
        TextButton(onPressed: _begin, child: const Text('REINICIAR PARTIDA')),
      ],
    ),
  );

  Widget _buildResults() => _overlay(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.emoji_events_rounded,
          color: Color(0xFFFFD267),
          size: 58,
        ),
        const SizedBox(height: 8),
        const Text(
          'RESULTADOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 17),
        _resultRow('PUNTUACIÓN', '${_game.score}'),
        _resultRow('ACIERTOS', '${_game.hits}'),
        _resultRow('DISPAROS', '${_game.shots}'),
        _resultRow('PRECISIÓN', '${_game.accuracy.toStringAsFixed(1)}%'),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _begin,
            icon: const Icon(Icons.refresh),
            label: const Text('VOLVER A JUGAR'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _backToCatalog,
          child: const Text('VOLVER AL INICIO'),
        ),
      ],
    ),
  );

  Widget _resultRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9CB5D9),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _buildError() => _overlay(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.sensors_off_rounded,
          color: Color(0xFFFF9A9A),
          size: 52,
        ),
        const SizedBox(height: 10),
        const Text(
          'GIROSCOPIO NO DISPONIBLE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'No se pudo acceder al giroscopio de este dispositivo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFD3E1F5)),
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: _backToCatalog,
          child: const Text('VOLVER AL INICIO'),
        ),
      ],
    ),
  );
}

class _GyroAimPainter extends CustomPainter {
  const _GyroAimPainter(this.game);

  final GyroAimGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF101D35), Color(0xFF07101F)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final playTop = math.min(138.0, size.height * 0.25);
    final playBottom = math.max(playTop + 180.0, size.height - 118.0);
    final playRect = Rect.fromLTRB(12, playTop, size.width - 12, playBottom);
    canvas.drawRRect(
      RRect.fromRectAndRadius(playRect, const Radius.circular(22)),
      Paint()
        ..color = const Color(0x171F4E73)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(playRect, const Radius.circular(22)),
      Paint()
        ..color = const Color(0x335A96C6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final target = game.target;
    if (target != null) {
      final glow = Paint()
        ..color = const Color(0x9959E8FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13);
      canvas.drawCircle(target.position, target.radius * 1.15, glow);
      canvas.drawCircle(
        target.position,
        target.radius,
        Paint()..color = const Color(0xFFE55274),
      );
      canvas.drawCircle(
        target.position,
        target.radius * .66,
        Paint()..color = const Color(0xFFFFC65B),
      );
      canvas.drawCircle(
        target.position,
        target.radius * .26,
        Paint()..color = const Color(0xFFFDF7DC),
      );
      canvas.drawCircle(
        target.position,
        target.radius + 6,
        Paint()
          ..color = const Color(0xFF86F1FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    if (game.aimPosition != Offset.zero) {
      final aim = game.aimPosition;
      final radius = 22.0;
      final color = game.hitFlash > 0
          ? const Color(0xFF7AFFA9)
          : game.missFlash > 0
          ? const Color(0xFFFF9A9A)
          : const Color(0xFF72EAFF);
      canvas.drawCircle(
        aim,
        radius + 9,
        Paint()
          ..color = color.withValues(alpha: .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(aim, radius, linePaint);
      canvas.drawLine(
        aim + const Offset(-34, 0),
        aim + const Offset(-11, 0),
        linePaint,
      );
      canvas.drawLine(
        aim + const Offset(11, 0),
        aim + const Offset(34, 0),
        linePaint,
      );
      canvas.drawLine(
        aim + const Offset(0, -34),
        aim + const Offset(0, -11),
        linePaint,
      );
      canvas.drawLine(
        aim + const Offset(0, 11),
        aim + const Offset(0, 34),
        linePaint,
      );
      canvas.drawCircle(aim, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _GyroAimPainter oldDelegate) => true;
}
