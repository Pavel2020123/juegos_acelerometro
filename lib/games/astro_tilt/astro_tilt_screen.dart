import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app_logo.dart';
import '../../core/audio/audio_service.dart';
import '../../core/sensors/accelerometer_service.dart';
import '../../core/theme/app_theme.dart';
import 'astro_tilt_game.dart';
import 'astro_tilt_level.dart';

class AstroTiltScreen extends StatefulWidget {
  const AstroTiltScreen({
    required this.level,
    this.accelerometerService,
    super.key,
  });

  final AstroTiltLevel level;
  final AccelerometerService? accelerometerService;

  @override
  State<AstroTiltScreen> createState() => _AstroTiltScreenState();
}

class _AstroTiltScreenState extends State<AstroTiltScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AstroTiltGame _game;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = AstroTiltGame(
      level: widget.level,
      accelerometerService: widget.accelerometerService,
      onAudioEvent: (event) {
        switch (event) {
          case AstroAudioEvent.mainShot:
            AppAudio.instance.play(AppSound.mainShot);
          case AstroAudioEvent.droneShot:
            AppAudio.instance.play(AppSound.droneShot);
          case AstroAudioEvent.victory:
            AppAudio.instance.setGamePaused(true);
            AppAudio.instance.play(AppSound.victory);
          case AstroAudioEvent.defeat:
            AppAudio.instance.setGamePaused(true);
            AppAudio.instance.play(AppSound.defeat);
        }
      },
    );
    AppAudio.instance.setGamePaused(false);
    AppAudio.instance.claimSilence(this);
    _ticker = createTicker((elapsed) {
      final delta =
          (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
      _lastTick = elapsed;
      _game.update(delta.clamp(0.0, 0.1));
    })..start();
  }

  @override
  void dispose() {
    AppAudio.instance.releaseMusic(this);
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_game.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _game.phase != AstroTiltPhase.paused &&
        _game.phase != AstroTiltPhase.victory &&
        _game.phase != AstroTiltPhase.defeated) {
      _game.pause();
      AppAudio.instance.setGamePaused(true);
    }
  }

  void _resume() {
    _game.resume();
    AppAudio.instance.setGamePaused(false);
  }

  void _restart() {
    _game.restart();
    AppAudio.instance.setGamePaused(false);
    AppAudio.instance.claimSilence(this);
  }

  void _calibrate() {
    if (_game.calibrate()) {
      AppAudio.instance.claimMusic(this, AppAudio.astroTrack(widget.level.id));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se detecta el acelerómetro. Activa CONTROL: TÁCTIL para jugar.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _moveJoystick(Offset point) {
    const center = 59.0;
    const radius = 43.0;
    _game.setTouchInput(
      Offset((point.dx - center) / radius, (point.dy - center) / radius),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _game.setViewport(constraints.biggest);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _AstroScenePainter(_game)),
              SafeArea(
                child: AnimatedBuilder(
                  animation: _game,
                  builder: (context, _) => Stack(
                    children: [
                      _buildHud(),
                      if (_game.phase == AstroTiltPhase.calibrating)
                        _buildCalibration(),
                      if (_game.phase == AstroTiltPhase.countdown)
                        _buildCountdown(),
                      if (_game.phase == AstroTiltPhase.paused) _buildPaused(),
                      if (_game.phase == AstroTiltPhase.victory ||
                          _game.phase == AstroTiltPhase.defeated)
                        _buildResults(),
                      if (_game.touchMode &&
                          _game.phase == AstroTiltPhase.playing)
                        _buildJoystick(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHud() => Positioned(
    top: 8,
    left: 14,
    right: 14,
    child: Column(
      children: [
        Row(
          children: [
            _hudButton(
              icon: Icons.arrow_back,
              tooltip: 'Volver a niveles',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            const AppLogo(size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ASTROTILT',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'NIVEL ${widget.level.id.toString().padLeft(2, '0')}  ·  ${widget.level.name.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD2E1F4),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            _hudButton(
              icon: _game.touchMode ? Icons.touch_app : Icons.screen_rotation,
              tooltip: _game.touchMode ? 'CONTROL: TÁCTIL' : 'CONTROL: SENSOR',
              onPressed: () => _game.setTouchMode(!_game.touchMode),
            ),
            const SizedBox(width: 6),
            _hudButton(
              icon: Icons.pause_rounded,
              tooltip: 'Pausar',
              onPressed:
                  _game.phase == AstroTiltPhase.playing ||
                      _game.phase == AstroTiltPhase.countdown
                  ? () {
                      _game.pause();
                      AppAudio.instance.setGamePaused(true);
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: _statPanel(
                label: 'VIDA',
                value: '${(_game.healthFraction * 100).round()}%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: _game.healthFraction,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2EAF5),
                    color: _game.healthFraction < 0.35
                        ? const Color(0xFFE66C62)
                        : AppColors.secondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _statPanel(
                label: 'PUNTOS',
                value: _game.score.toString().padLeft(5, '0'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _statPanel(
                label: 'COMBO',
                value: 'x${_game.combo}',
                valueColor: const Color(0xFFB96A12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_game.elapsed / widget.level.duration).clamp(
                    0.0,
                    1.0,
                  ),
                  minHeight: 3,
                  backgroundColor: const Color(0xFFE2EAF5),
                  color: AppColors.astroTilt,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_game.remaining.ceil()} s',
              style: const TextStyle(
                color: Color(0xFFD2E1F4),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_game.shieldActive) ...[
              const SizedBox(width: 8),
              const Icon(Icons.shield, size: 14, color: Color(0xFF85E5FF)),
              Text(
                '${_game.shieldTime.ceil()}s',
                style: const TextStyle(color: Color(0xFFB8EEFF), fontSize: 10),
              ),
            ],
            if (_game.doubleShotActive) ...[
              const SizedBox(width: 7),
              const Icon(Icons.bolt, size: 14, color: Color(0xFFFFC267)),
              Text(
                '${_game.doubleShotTime.ceil()}s',
                style: const TextStyle(color: Color(0xFFFFD28A), fontSize: 10),
              ),
            ],
          ],
        ),
        if (widget.level.id >= 2) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'ESPECIAL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: LinearProgressIndicator(
                  value: _game.specialEnergy / 100,
                  minHeight: 5,
                  color: const Color(0xFFFFD26F),
                ),
              ),
              if (_game.specialReady)
                TextButton(
                  onPressed: _game.activateSpecial,
                  child: const Text('PULSO'),
                ),
            ],
          ),
          Wrap(
            spacing: 10,
            children: [
              if (_game.drones.isNotEmpty)
                Text(
                  'DRONE ${_game.drones.first.remaining.ceil()}s',
                  style: const TextStyle(
                    color: Color(0xFF9BE9FA),
                    fontSize: 10,
                  ),
                ),
              if (_game.tripleShotTime > 0)
                Text(
                  'TRIPLE ${_game.tripleShotTime.ceil()}s',
                  style: const TextStyle(
                    color: Color(0xFFFFD28A),
                    fontSize: 10,
                  ),
                ),
              if (_game.missileTime > 0)
                Text(
                  'MISILES ${_game.missileTime.ceil()}s',
                  style: const TextStyle(
                    color: Color(0xFFFFD28A),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
        if (_game.boss case final boss?) ...[
          const SizedBox(height: 7),
          Row(
            children: [
              const Text(
                'GUARDIÁN',
                style: TextStyle(
                  color: Color(0xFFFFA078),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: boss.health / boss.maxHealth,
                    minHeight: 5,
                    backgroundColor: const Color(0xFF512C50),
                    color: const Color(0xFFFF7B91),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _statPanel({
    required String label,
    required String value,
    Widget? child,
    Color valueColor = AppColors.textPrimary,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xEFFFFFFF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFDCE5F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2020334D),
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        if (child != null) ...[const SizedBox(height: 5), child],
      ],
    ),
  );

  Widget _hudButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: 38,
    height: 38,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      iconSize: 18,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xEFFFFFFF),
        foregroundColor: AppColors.textPrimary,
        disabledBackgroundColor: const Color(0xAAFFFFFF),
        side: const BorderSide(color: Color(0x99FFFFFF)),
      ),
      icon: Icon(icon),
    ),
  );

  Widget _overlayCard({required Widget child}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xF7FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2220334D),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );

  Widget _buildCalibration() => _overlayCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.sensors, size: 42, color: AppColors.astroTilt),
        const SizedBox(height: 12),
        const Text(
          'LISTO PARA DESPEGAR',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Sostén el teléfono cómodamente. Inclínalo para mover la nave y mantén el control con movimientos suaves.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        _primaryButton(
          label: _game.touchMode ? 'EMPEZAR MISIÓN' : 'CALIBRAR',
          icon: Icons.rocket_launch,
          onPressed: _calibrate,
        ),
        const SizedBox(height: 8),
        Text(
          _game.touchMode
              ? 'CONTROL: TÁCTIL ACTIVADO'
              : _game.sensorError != null
              ? 'FALLO DEL ACELERÓMETRO · ACTIVA CONTROL TÁCTIL'
              : _game.sensorAvailable
              ? 'ACELERÓMETRO CONECTADO'
              : 'CONTROL SENSORIAL · TAMBIÉN PUEDES USAR TÁCTIL',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.7,
          ),
        ),
      ],
    ),
  );

  Widget _buildCountdown() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _game.countdown <= 0.65 ? '¡DESPEGA!' : '${_game.countdown.ceil()}',
          style: TextStyle(
            color: Colors.white,
            fontSize: _game.countdown <= 0.65 ? 34 : 82,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Color(0x802563EB), blurRadius: 24)],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'PILOTA CON INCLINACIONES SUAVES',
          style: TextStyle(
            color: Color(0xFFE2EEFF),
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
      ],
    ),
  );

  Widget _buildPaused() => _overlayCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.pause_circle, size: 48, color: AppColors.astroTilt),
        const SizedBox(height: 8),
        const Text(
          'MISIÓN EN PAUSA',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 20),
        _primaryButton(
          label: 'CONTINUAR',
          icon: Icons.play_arrow,
          onPressed: _resume,
        ),
        const SizedBox(height: 9),
        TextButton(onPressed: _restart, child: const Text('REINICIAR MISIÓN')),
      ],
    ),
  );

  Widget _buildResults() {
    final victory = _game.phase == AstroTiltPhase.victory;
    return _overlayCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            victory ? Icons.emoji_events : Icons.favorite_border,
            size: 46,
            color: victory ? const Color(0xFFFFCA72) : const Color(0xFFFF8F86),
          ),
          const SizedBox(height: 10),
          Text(
            victory ? _game.victoryMessage : 'NAVE FUERA DE SERVICIO',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (victory)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Icon(
                  Icons.star_rounded,
                  size: 34,
                  color: index < _game.stars
                      ? const Color(0xFFFFCC70)
                      : const Color(0xFFDCE4EF),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _resultLine('PUNTOS', _game.score.toString()),
          _resultLine('ENEMIGOS DESTRUIDOS', '${_game.enemiesDestroyed}'),
          _resultLine('COMBO MÁXIMO', 'x${_game.maxCombo}'),
          _resultLine('VIDA RESTANTE', '${_game.health.round()}%'),
          if (widget.level.hasBoss)
            _resultLine(
              'GUARDIÁN',
              _game.bossDefeated ? 'DERROTADO' : 'EN PIE',
            ),
          const SizedBox(height: 16),
          _primaryButton(
            label: victory && widget.level.id < astroTiltLevels.length
                ? 'SIGUIENTE NIVEL'
                : 'REINTENTAR',
            icon: victory && widget.level.id < astroTiltLevels.length
                ? Icons.arrow_forward
                : Icons.replay,
            onPressed: victory && widget.level.id < astroTiltLevels.length
                ? _openNextLevel
                : _restart,
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('VOLVER A NIVELES'),
          ),
        ],
      ),
    );
  }

  Widget _resultLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _buildJoystick() => Positioned(
    left: 18,
    bottom: 16,
    child: SafeArea(
      child: GestureDetector(
        onPanStart: (details) => _moveJoystick(details.localPosition),
        onPanUpdate: (details) => _moveJoystick(details.localPosition),
        onPanEnd: (_) => _game.setTouchInput(Offset.zero),
        onPanCancel: () => _game.setTouchInput(Offset.zero),
        child: Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xDFFFFFFF),
            border: Border.all(color: const Color(0xFF9CC5E7), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x2220334D), blurRadius: 14),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.control_camera,
              color: AppColors.astroTilt,
              size: 38,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );

  void _openNextLevel() {
    final next = nextAstroTiltLevel(widget.level);
    if (next == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AstroTiltScreen(level: next)),
    );
  }
}

class _AstroScenePainter extends CustomPainter {
  _AstroScenePainter(this.game) : super(repaint: game);

  final AstroTiltGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A1733), Color(0xFF101B3C), Color(0xFF11132F)],
      ).createShader(bounds);
    canvas.drawRect(bounds, background);
    _drawNebula(canvas, size);
    _drawStars(canvas, size);
    _drawObjects(canvas);
    _drawPlayer(canvas);
  }

  void _drawNebula(Canvas canvas, Size size) {
    final clouds = [
      (
        Offset(size.width * 0.16, size.height * 0.42),
        size.width * 0.38,
        const Color(0x223E7BCE),
      ),
      (
        Offset(size.width * 0.88, size.height * 0.64),
        size.width * 0.36,
        const Color(0x222D4B9B),
      ),
      (
        Offset(size.width * 0.53, size.height * 0.92),
        size.width * 0.50,
        const Color(0x182A61A0),
      ),
    ];
    for (final cloud in clouds) {
      canvas.drawCircle(
        cloud.$1,
        cloud.$2,
        Paint()
          ..color = cloud.$3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    final elapsed = game.elapsed;
    for (var index = 0; index < 58; index++) {
      final x = ((index * 73 + 19) % 997) / 997 * size.width;
      final baseY = ((index * 137 + 41) % 991) / 991 * size.height;
      final speed = 13 + index % 5 * 7;
      final y = (baseY + elapsed * speed) % size.height;
      final radius = index % 9 == 0 ? 1.7 : 0.8 + index % 3 * 0.25;
      final opacity = 0.25 + (index % 5) * 0.1;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Color.fromRGBO(181, 228, 255, opacity),
      );
      if (index % 13 == 0) {
        canvas.drawLine(
          Offset(x, y + 5),
          Offset(x, y + 15 + speed * 0.15),
          Paint()
            ..color = const Color(0x334CD6FA)
            ..strokeWidth = 1,
        );
      }
    }
  }

  void _drawObjects(Canvas canvas) {
    for (final drone in game.drones) {
      final paint = Paint()
        ..color = const Color(0xFF69E4F4).withValues(alpha: drone.opacity);
      canvas.drawCircle(
        drone.position,
        13,
        Paint()
          ..color = const Color(0x5569E4F4)
              .withValues(alpha: drone.opacity * 0.33)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      final path = Path()
        ..moveTo(drone.position.dx, drone.position.dy - 11)
        ..lineTo(drone.position.dx + 9, drone.position.dy + 7)
        ..lineTo(drone.position.dx, drone.position.dy + 3)
        ..lineTo(drone.position.dx - 9, drone.position.dy + 7)
        ..close();
      canvas.drawPath(path, paint);
    }
    for (final meteor in game.meteors) {
      _drawMeteor(canvas, meteor);
    }
    for (final enemy in game.enemies) {
      _drawEnemy(canvas, enemy);
    }
    for (final projectile in game.projectiles) {
      _drawProjectile(canvas, projectile);
    }
    for (final powerUp in game.powerUps) {
      _drawPowerUp(canvas, powerUp);
    }
    for (final explosion in game.explosions) {
      _drawExplosion(canvas, explosion);
    }
    if (game.boss case final boss?) _drawBoss(canvas, boss);
  }

  void _drawPlayer(Canvas canvas) {
    final player = game.playerPosition;
    if (player == Offset.zero) return;
    if (game.invulnerability > 0 &&
        (game.invulnerability * 12).floor().isEven) {
      return;
    }
    final radius = (game.viewport.shortestSide * 0.045).clamp(18.0, 25.0);
    if (game.pulseTime > 0) {
      final progress = 1 - game.pulseTime / 0.45;
      canvas.drawCircle(
        player,
        radius + progress * game.viewport.shortestSide * 0.75,
        Paint()
          ..color = const Color(0xFF8EEDFF)
              .withValues(alpha: (1 - progress) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
    if (game.damageFlash > 0) {
      canvas.drawCircle(
        player,
        radius * 1.45,
        Paint()
          ..color = Color.fromRGBO(
            255,
            116,
            128,
            (game.damageFlash / 0.32 * 0.32).clamp(0.0, 0.32),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }
    if (game.shieldActive) {
      canvas.drawCircle(
        player,
        radius * (1.45 + math.sin(game.elapsed * 5) * 0.04),
        Paint()..color = const Color(0x336BEAFF),
      );
      canvas.drawCircle(
        player,
        radius * 1.52,
        Paint()
          ..color = const Color(0x5545DDFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
      canvas.drawCircle(
        player,
        radius * 1.46,
        Paint()
          ..color = const Color(0x1F6BEAFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    canvas.save();
    canvas.translate(player.dx, player.dy);
    canvas.rotate((game.velocity.dx / 300).clamp(-0.2, 0.2));

    final flame = Path()
      ..moveTo(-radius * 0.25, radius * 0.48)
      ..lineTo(0, radius * (1.02 + 0.15 * math.sin(game.elapsed * 13)))
      ..lineTo(radius * 0.25, radius * 0.48)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF78FFFF), Color(0xFF1688FF), Color(0x0073EFFF)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );

    final wings = Path()
      ..moveTo(-radius * 0.22, -radius * 0.04)
      ..lineTo(-radius * 1.05, radius * 0.55)
      ..lineTo(-radius * 0.56, radius * 0.60)
      ..lineTo(-radius * 0.36, radius * 0.29)
      ..lineTo(radius * 0.36, radius * 0.29)
      ..lineTo(radius * 0.56, radius * 0.60)
      ..lineTo(radius * 1.05, radius * 0.55)
      ..lineTo(radius * 0.22, -radius * 0.04)
      ..close();
    canvas.drawPath(
      wings,
      Paint()
        ..color = const Color(0xFF2477D8)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      wings,
      Paint()
        ..color = const Color(0xFF75DFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final body = Path()
      ..moveTo(0, -radius)
      ..quadraticBezierTo(
        radius * 0.42,
        -radius * 0.5,
        radius * 0.34,
        radius * 0.45,
      )
      ..lineTo(0, radius * 0.66)
      ..lineTo(-radius * 0.34, radius * 0.45)
      ..quadraticBezierTo(-radius * 0.42, -radius * 0.5, 0, -radius)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFF8CDFFF), Color(0xFF367BEA)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -radius * 0.18),
        width: radius * 0.29,
        height: radius * 0.5,
      ),
      Paint()..color = const Color(0xFF36B8FF),
    );
    canvas.restore();
  }

  void _drawEnemy(Canvas canvas, AstroEnemy enemy) {
    final center = enemy.position;
    final size = enemy.radius;
    final isFast = enemy.kind == AstroEnemyKind.fast;
    final color = switch (enemy.kind) {
      AstroEnemyKind.basic => const Color(0xFFFF846F),
      AstroEnemyKind.zigzag => const Color(0xFFB78BFF),
      AstroEnemyKind.fast => const Color(0xFFFFB45F),
    };
    canvas.drawCircle(
      center,
      size * 1.5,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final hull = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy - size * 0.05)
      ..lineTo(center.dx + size * 0.66, center.dy + size * 0.72)
      ..lineTo(center.dx, center.dy + size * 0.47)
      ..lineTo(center.dx - size * 0.66, center.dy + size * 0.72)
      ..lineTo(center.dx - size, center.dy - size * 0.05)
      ..close();
    canvas.drawPath(hull, Paint()..color = color);
    canvas.drawPath(
      hull,
      Paint()
        ..color = const Color(0xFFFFE2CD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size * 0.58, height: size * 0.35),
      Paint()
        ..color = isFast ? const Color(0xFFFFF0B0) : const Color(0xFFFFC1A0),
    );
  }

  void _drawMeteor(Canvas canvas, AstroMeteor meteor) {
    final center = meteor.position;
    final radius = meteor.radius;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(meteor.rotation);
    final rock = Path()
      ..moveTo(-radius * 0.76, -radius * 0.33)
      ..lineTo(-radius * 0.32, -radius * 0.92)
      ..lineTo(radius * 0.4, -radius * 0.8)
      ..lineTo(radius * 0.92, -radius * 0.2)
      ..lineTo(radius * 0.68, radius * 0.62)
      ..lineTo(radius * 0.05, radius * 0.95)
      ..lineTo(-radius * 0.72, radius * 0.62)
      ..lineTo(-radius, radius * 0.12)
      ..close();
    canvas.drawPath(
      rock,
      Paint()
        ..color = const Color(0xFF9C695A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(rock, Paint()..color = const Color(0xFF765B61));
    canvas.drawPath(
      rock,
      Paint()
        ..color = const Color(0xFFD29469)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    for (final mark in [
      Offset(-radius * 0.36, -radius * 0.15),
      Offset(radius * 0.30, radius * 0.32),
      Offset(radius * 0.35, -radius * 0.40),
    ]) {
      canvas.drawCircle(
        mark,
        radius * 0.13,
        Paint()..color = const Color(0xFF493E50),
      );
    }
    canvas.restore();
  }

  void _drawProjectile(Canvas canvas, AstroProjectile projectile) {
    final color = switch (projectile.kind) {
      AstroProjectileKind.drone => const Color(0xFF95BEFF),
      AstroProjectileKind.missile => const Color(0xFFFFD17D),
      _ =>
        projectile.fromPlayer
            ? const Color(0xFF6FFAFF)
            : const Color(0xFFFF7F9A),
    };
    final paint = Paint()
      ..color = color
      ..strokeWidth = projectile.fromPlayer ? 3.5 : 4.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(
      projectile.position - projectile.velocity * 0.035,
      projectile.position + projectile.velocity * 0.012,
      paint,
    );
    canvas.drawCircle(
      projectile.position,
      projectile.radius,
      Paint()..color = color,
    );
  }

  void _drawPowerUp(Canvas canvas, AstroPowerUp powerUp) {
    final color = switch (powerUp.kind) {
      AstroPowerUpKind.shield => const Color(0xFF63DFFF),
      AstroPowerUpKind.doubleShot => const Color(0xFFFFCA73),
      AstroPowerUpKind.repair => const Color(0xFF71E6A1),
      AstroPowerUpKind.drone => const Color(0xFF8BB9FF),
      AstroPowerUpKind.tripleShot => const Color(0xFFFFAD65),
      AstroPowerUpKind.missiles => const Color(0xFFFF8181),
      AstroPowerUpKind.energy => const Color(0xFFFFE279),
    };
    canvas.drawCircle(
      powerUp.position,
      18,
      Paint()
        ..color = color.withValues(alpha: 0.23)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(
      powerUp.position,
      13,
      Paint()
        ..color = const Color(0xDD112544)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      powerUp.position,
      13,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final mark = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (powerUp.kind) {
      case AstroPowerUpKind.shield:
        final shield = Path()
          ..moveTo(powerUp.position.dx, powerUp.position.dy - 7)
          ..lineTo(powerUp.position.dx + 6, powerUp.position.dy - 4)
          ..lineTo(powerUp.position.dx + 5, powerUp.position.dy + 2)
          ..lineTo(powerUp.position.dx, powerUp.position.dy + 7)
          ..lineTo(powerUp.position.dx - 5, powerUp.position.dy + 2)
          ..lineTo(powerUp.position.dx - 6, powerUp.position.dy - 4)
          ..close();
        canvas.drawPath(shield, mark);
      case AstroPowerUpKind.doubleShot:
        canvas
          ..drawLine(
            powerUp.position + const Offset(-3, -6),
            powerUp.position + const Offset(-3, 6),
            mark,
          )
          ..drawLine(
            powerUp.position + const Offset(3, -6),
            powerUp.position + const Offset(3, 6),
            mark,
          );
      case AstroPowerUpKind.repair:
        canvas
          ..drawLine(
            powerUp.position + const Offset(-5, 0),
            powerUp.position + const Offset(5, 0),
            mark,
          )
          ..drawLine(
            powerUp.position + const Offset(0, -5),
            powerUp.position + const Offset(0, 5),
            mark,
          );
      case AstroPowerUpKind.drone:
      case AstroPowerUpKind.tripleShot:
      case AstroPowerUpKind.missiles:
      case AstroPowerUpKind.energy:
        final label = switch (powerUp.kind) {
          AstroPowerUpKind.drone => 'D',
          AstroPowerUpKind.tripleShot => '3',
          AstroPowerUpKind.missiles => 'M',
          _ => 'E',
        };
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          powerUp.position - Offset(painter.width / 2, painter.height / 2),
        );
    }
  }

  void _drawExplosion(Canvas canvas, AstroExplosion explosion) {
    final progress = (explosion.age / 0.5).clamp(0.0, 1.0);
    final color = Color(explosion.color);
    canvas.drawCircle(
      explosion.position,
      6 + progress * 25,
      Paint()
        ..color = color.withValues(alpha: (1 - progress) * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - progress) + 0.5,
    );
    canvas.drawCircle(
      explosion.position,
      4 + progress * 8,
      Paint()..color = color.withValues(alpha: 1 - progress),
    );
    for (var particle = 0; particle < 8; particle++) {
      final angle = particle * math.pi / 4;
      final distance = 5 + progress * 22;
      canvas.drawCircle(
        explosion.position +
            Offset(math.cos(angle), math.sin(angle)) * distance,
        1.4 * (1 - progress) + 0.4,
        Paint()..color = color.withValues(alpha: 1 - progress),
      );
    }
  }

  void _drawBoss(Canvas canvas, AstroBoss boss) {
    final center = boss.position;
    final radius = boss.radius;
    canvas.drawCircle(
      center,
      radius * 1.25,
      Paint()
        ..color = const Color(0x33E84C9B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    final hull = Path()
      ..moveTo(center.dx, center.dy - radius * 0.84)
      ..lineTo(center.dx + radius * 0.43, center.dy - radius * 0.6)
      ..lineTo(center.dx + radius, center.dy - radius * 0.16)
      ..lineTo(center.dx + radius * 0.75, center.dy + radius * 0.33)
      ..lineTo(center.dx + radius * 0.24, center.dy + radius * 0.12)
      ..lineTo(center.dx, center.dy + radius * 0.55)
      ..lineTo(center.dx - radius * 0.24, center.dy + radius * 0.12)
      ..lineTo(center.dx - radius * 0.75, center.dy + radius * 0.33)
      ..lineTo(center.dx - radius, center.dy - radius * 0.16)
      ..lineTo(center.dx - radius * 0.43, center.dy - radius * 0.6)
      ..close();
    canvas.drawPath(
      hull,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF99AC), Color(0xFF9C5EDF), Color(0xFF354FC0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawPath(
      hull,
      Paint()
        ..color = const Color(0xFFFFC3D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 0.56,
        height: radius * 0.33,
      ),
      Paint()..color = const Color(0xFFFFE5AE),
    );
    canvas.drawOval(
      Rect.fromLTWH(
        center.dx - radius * 0.42,
        center.dy + radius + 9,
        radius * 0.84,
        5,
      ),
      Paint()..color = const Color(0xAA321F48),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - radius * 0.42,
        center.dy + radius + 9,
        radius * 0.84 * boss.health / boss.maxHealth,
        5,
      ),
      Paint()..color = const Color(0xFFFF7F9D),
    );
  }

  @override
  bool shouldRepaint(covariant _AstroScenePainter oldDelegate) =>
      oldDelegate.game != game;
}
