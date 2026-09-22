import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'tilt_maze_level.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../core/sensors/accelerometer_service.dart';

// ============================================================
// ESTADO DEL HUD
// ============================================================

class TiltMazeHudState {
  const TiltMazeHudState({
    required this.time,
    required this.checkpoint,
    required this.totalCheckpoints,
    required this.completed,
    required this.falling,
  });

  final double time;
  final int checkpoint;
  final int totalCheckpoints;
  final bool completed;
  final bool falling;
}

// ============================================================
// JUEGO
// ============================================================

class TiltMazeGame extends FlameGame {
  TiltMazeGame({
    required this.level,
    AccelerometerService? accelerometerService,
  }) : _accelerometerService =
            accelerometerService ?? AccelerometerService();

  final TiltMazeLevel level;

  // ============================================================
  // CONFIGURACIÓN
  // ============================================================

  static const double _ballRadius = 16;
  static const double _sensitivity = 180;
  static const double _friction = 4.5;
  static const double _iceFriction = 0.65;
  static const double _deadZone = 0.15;
  static const double _maxSpeed = 500;

  // En tu teléfono X estaba invertido.
  static const double xDirection = -1;
  static const double yDirection = 1;

  // ============================================================
  // COLORES
  // ============================================================

  static const Color _backgroundColor = Color(0xFF050711);

  static const Color _trackTopColor = Color(0xFF17233B);
  static const Color _trackShadowColor = Color(0xFF070A12);
  static const Color _trackGlowColor = Color(0xFF536DFF);

  static const Color _ballColor = Color(0xFF8B6CFF);
  static const Color _ballCoreColor = Color(0xFFE8E1FF);

  static const Color _goalColor = Color(0xFF35E69A);
  static const Color _checkpointColor = Color(0xFFFFC857);
  static const Color _startColor = Color(0xFF38BDF8);

  // ============================================================
  // SENSOR
  // ============================================================

  final AccelerometerService _accelerometerService;

  final ValueNotifier<AccelerometerReading> currentReading =
      ValueNotifier<AccelerometerReading>(
    const AccelerometerReading(
      x: 0,
      y: 0,
      z: 0,
      magnitude: 0,
    ),
  );

  final ValueNotifier<TiltMazeHudState> hud =
      ValueNotifier<TiltMazeHudState>(
    const TiltMazeHudState(
      time: 0,
      checkpoint: 0,
      totalCheckpoints: 2,
      completed: false,
      falling: false,
    ),
  );

  StreamSubscription<AccelerometerReading>? _readingSubscription;

  // ============================================================
  // ELEMENTOS
  // ============================================================

  GlowingBallComponent? _ball;

  final List<Component> _levelComponents = [];
  final List<Rect> _trackRects = [];
  final List<Rect> _checkpointRects = [];

  final List<Rect> _iceZoneRects = [];

  final List<MovingLaserComponent> _lasers = [];

  bool _onIce = false;

  GoalPortalComponent? _portal;

  Rect? _goalRect;

  Vector2 _velocity = Vector2.zero();
  Vector2 _smoothedAcceleration = Vector2.zero();

  Vector2 _startPosition = Vector2.zero();
  Vector2 _respawnPosition = Vector2.zero();

  // ============================================================
  // ESTADO
  // ============================================================

  bool _levelReady = false;
  bool _completed = false;
  bool _falling = false;
  bool _closed = false;

  int _currentCheckpoint = 0;

  double _elapsedTime = 0;
  double _hudAccumulator = 0;
  double _fallTimer = 0;

  @override
  Color backgroundColor() => _backgroundColor;

  // ============================================================
  // LOAD
  // ============================================================

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Fondo espacial.
    await add(
      StarFieldComponent(
        priority: -100,
      ),
    );

    // Bola.
    final ball = GlowingBallComponent(
      radius: _ballRadius,
      position: Vector2.zero(),
      priority: 30,
    );

    _ball = ball;

    await add(ball);

    if (size.x > 0 && size.y > 0) {
      _buildLevel();
    }

    // Sensor.
    _readingSubscription =
        _accelerometerService.readings.listen((reading) {
      currentReading.value = reading;

      _smoothedAcceleration = Vector2(
        _smoothAxis(
          _smoothedAcceleration.x,
          reading.x * xDirection,
        ),
        _smoothAxis(
          _smoothedAcceleration.y,
          reading.y * yDirection,
        ),
      );
    });

    _accelerometerService.start();
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);

    if (_ball == null) {
      return;
    }

    if (newSize.x <= 0 || newSize.y <= 0) {
      return;
    }

    _buildLevel();
  }

  // ============================================================
  // CREAR NIVEL
  // ============================================================

  void _buildLevel() {
    if (size.x <= 0 || size.y <= 0) {
      return;
    }

    for (final component in _levelComponents) {
      component.removeFromParent();
    }

    _levelComponents.clear();
    _trackRects.clear();
    _checkpointRects.clear();
    _iceZoneRects.clear();
    _lasers.clear();

    _portal = null;
    _onIce = false;

    const double topArea = 160;

    final double bottom = size.y - 55;

    final double usableHeight = math.max(
      200,
      bottom - topArea,
    );

    final double trackWidth = math.min(
          100,
          size.x * level.trackWidthFactor,
    );

      // Convertimos las coordenadas normalizadas del nivel
      // a coordenadas reales de pantalla.
      final List<Vector2> path = level.path.map((point) {
        return Vector2(
          size.x * point.x,
          topArea + usableHeight * point.y,
        );
      }).toList();

    // Pista.
    for (int i = 0; i < path.length - 1; i++) {
      _createTrackSegment(
        path[i],
        path[i + 1],
        trackWidth,
      );
    }

    // ============================================================
    // INICIO
    // ============================================================

    _startPosition = path.first.clone();
    _respawnPosition = _startPosition.clone();

    final startPlatform = StartPlatformComponent(
      position: _startPosition.clone(),
      radius: 34,
      priority: 5,
    );

    _levelComponents.add(startPlatform);

    add(startPlatform);

    // ============================================================
    // CHECKPOINT 1
    // ============================================================

    // ============================================================
// CHECKPOINTS DEL NIVEL
// ============================================================

    for (int i = 0; i < level.checkpointIndexes.length; i++) {
      final pathIndex = level.checkpointIndexes[i];

      if (pathIndex >= 0 && pathIndex < path.length) {
        _createCheckpoint(
          path[pathIndex],
          i + 1,
        );
      }
    }

          // ============================================================
      // ZONAS DE HIELO
      // ============================================================

      for (final ice in level.iceZones) {
        final rect = Rect.fromCenter(
          center: Offset(
            size.x * ice.x,
            topArea + usableHeight * ice.y,
          ),
          width: size.x * ice.width,
          height: usableHeight * ice.height,
        );

        _iceZoneRects.add(rect);

        final iceZone = IceZoneComponent(
          position: Vector2(
            rect.left,
            rect.top,
          ),
          size: Vector2(
            rect.width,
            rect.height,
          ),
          priority: 6,
        );

        _levelComponents.add(iceZone);

        add(iceZone);
      }

        // ============================================================
    // LÁSERES DEL NIVEL
    // ============================================================

    for (final laserConfig in level.lasers) {
      final laserCenter = Vector2(
        size.x * laserConfig.x,
        topArea + usableHeight * laserConfig.y,
      );

      final laser = MovingLaserComponent(
        centerPosition: laserCenter,
        movementWidth: trackWidth * 0.85,
        laserLength: trackWidth * 0.90,
        speed: laserConfig.speed,
        movementFactor: laserConfig.movement,
        priority: 15,
      );

      _lasers.add(laser);

      _levelComponents.add(laser);

      add(laser);
    }

    // ============================================================
    // PORTAL META
    // ============================================================

    final goalCenter = path.last;

    const double goalSize = 74;

    _goalRect = Rect.fromCenter(
      center: Offset(
        goalCenter.x,
        goalCenter.y,
      ),
      width: goalSize,
      height: goalSize,
    );

    final portal = GoalPortalComponent(
      position: goalCenter.clone(),
      radius: goalSize / 2,
      priority: 8,
    );

    _portal = portal;

    _levelComponents.add(portal);

    add(portal);

    restartLevel();

    _levelReady = true;
  }

  // ============================================================
  // PISTA FLOTANTE
  // ============================================================

  void _createTrackSegment(
    Vector2 start,
    Vector2 end,
    double trackWidth,
  ) {
    Rect rect;

    final bool horizontal =
        (start.y - end.y).abs() <
            (start.x - end.x).abs();

    if (horizontal) {
      final left =
          math.min(start.x, end.x) - trackWidth / 2;

      final right =
          math.max(start.x, end.x) + trackWidth / 2;

      rect = Rect.fromLTRB(
        left,
        start.y - trackWidth / 2,
        right,
        start.y + trackWidth / 2,
      );
    } else {
      final top =
          math.min(start.y, end.y) - trackWidth / 2;

      final bottom =
          math.max(start.y, end.y) + trackWidth / 2;

      rect = Rect.fromLTRB(
        start.x - trackWidth / 2,
        top,
        start.x + trackWidth / 2,
        bottom,
      );
    }

    _trackRects.add(rect);

    // SOMBRA / PROFUNDIDAD
    final shadow = RectangleComponent(
      position: Vector2(
        rect.left + 8,
        rect.top + 10,
      ),
      size: Vector2(
        rect.width,
        rect.height,
      ),
      priority: 0,
      paint: Paint()
        ..color = _trackShadowColor.withValues(
          alpha: 0.9,
        ),
    );

    _levelComponents.add(shadow);

    add(shadow);

    // PLATAFORMA PRINCIPAL
    final track = RectangleComponent(
      position: Vector2(
        rect.left,
        rect.top,
      ),
      size: Vector2(
        rect.width,
        rect.height,
      ),
      priority: 1,
      paint: Paint()
        ..color = _trackTopColor,
    );

    _levelComponents.add(track);

    add(track);

    // BORDE LUMINOSO
    final glowBorder = RectangleComponent(
      position: Vector2(
        rect.left + 3,
        rect.top + 3,
      ),
      size: Vector2(
        math.max(
          1,
          rect.width - 6,
        ),
        math.max(
          1,
          rect.height - 6,
        ),
      ),
      priority: 2,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _trackGlowColor.withValues(
          alpha: 0.70,
        ),
    );

    _levelComponents.add(glowBorder);

    add(glowBorder);

    // LÍNEA CENTRAL SUAVE
    final centerLine = RectangleComponent(
      position: horizontal
          ? Vector2(
              rect.left + 12,
              rect.center.dy - 1,
            )
          : Vector2(
              rect.center.dx - 1,
              rect.top + 12,
            ),
      size: horizontal
          ? Vector2(
              math.max(
                1,
                rect.width - 24,
              ),
              2,
            )
          : Vector2(
              2,
              math.max(
                1,
                rect.height - 24,
              ),
            ),
      priority: 3,
      paint: Paint()
        ..color = Colors.white.withValues(
          alpha: 0.08,
        ),
    );

    _levelComponents.add(centerLine);

    add(centerLine);
  }

  // ============================================================
  // CHECKPOINT
  // ============================================================

  void _createCheckpoint(
    Vector2 center,
    int number,
  ) {
    const double checkpointSize = 64;

    final rect = Rect.fromCenter(
      center: Offset(
        center.x,
        center.y,
      ),
      width: checkpointSize,
      height: checkpointSize,
    );

    _checkpointRects.add(rect);

    final checkpoint = CheckpointComponent(
      position: center.clone(),
      number: number,
      radius: checkpointSize / 2,
      priority: 7,
    );

    _levelComponents.add(checkpoint);

    add(checkpoint);
  }

  // ============================================================
  // UPDATE
  // ============================================================

  @override
  void update(double dt) {
    super.update(dt);

    final ball = _ball;

    if (!_levelReady || ball == null) {
      return;
    }

    if (_completed) {
      return;
    }

    if (_falling) {
      _updateFall(dt);

      return;
    }

    // Tiempo.
    _elapsedTime += dt;

    _hudAccumulator += dt;

    if (_hudAccumulator >= 0.1) {
      _hudAccumulator = 0;

      _publishHud();
    }

    final seconds = dt.clamp(
      0.0,
      0.05,
    );

    // Acelerómetro.
    final input = Vector2(
      _applyDeadZone(
        _smoothedAcceleration.x,
      ),
      _applyDeadZone(
        _smoothedAcceleration.y,
      ),
    );

    // Física.
    _velocity +=
        input * _sensitivity * seconds;

    _checkIceZone();

    final currentFriction =
        _onIce ? _iceFriction : _friction;

    final damping =
        math.exp(-currentFriction * seconds);

    _velocity *= damping;

    if (_velocity.length > _maxSpeed) {
      _velocity =
          _velocity.normalized() *
              _maxSpeed;
    }

    ball.position +=
        _velocity * seconds;

    // ============================================================
    // CAÍDA
    // ============================================================

    if (!_isBallOnTrack()) {
      _startFall();

      return;
    }

    // ============================================================
    // CHECKPOINT
    // ============================================================

    _checkCheckpoints();

    // ============================================================
    // LÁSER
    // ============================================================

    _checkLaserCollision();

    if (_falling) {
      return;
    }

    // ============================================================
    // META
    // ============================================================

    final goal = _goalRect;

    if (goal != null &&
        goal.contains(
          Offset(
            ball.position.x,
            ball.position.y,
          ),
        )) {
      _completeLevel();
    }
  }

  // ============================================================
  // HIELO
  // ============================================================

  void _checkIceZone() {
  final ball = _ball;

  if (ball == null) {
    _onIce = false;
    return;
  }

  final point = Offset(
    ball.position.x,
    ball.position.y,
  );

  _onIce = _iceZoneRects.any(
    (rect) => rect.contains(point),
  );
}

  // ============================================================
  // LÁSER
  // ============================================================

  void _checkLaserCollision() {
  final ball = _ball;

  if (ball == null) {
    return;
  }

  for (final laser in _lasers) {
    if (laser.collidesWithBall(
      ball.position,
      _ballRadius,
    )) {
      _startFall();
      return;
    }
  }
}

  // ============================================================
  // CAÍDA
  // ============================================================

  void _startFall() {
    if (_falling) {
      return;
    }

    _falling = true;

    _fallTimer = 0;

    _velocity = Vector2.zero();

    _publishHud();
  }

  void _updateFall(double dt) {
    final ball = _ball;

    if (ball == null) {
      return;
    }

    _fallTimer += dt;

    const double fallDuration = 0.65;

    final progress =
        (_fallTimer / fallDuration).clamp(
      0.0,
      1.0,
    );

    final double scale =
        1 - progress * 0.85;

    ball.scale = Vector2.all(
      math.max(
        0.15,
        scale,
      ),
    );

    ball.opacity =
        1 - progress * 0.75;

    if (_fallTimer >= fallDuration) {
      _falling = false;

      ball.scale =
          Vector2.all(1);

      ball.opacity = 1;

      _respawnBall();

      _publishHud();
    }
  }

  // ============================================================
  // CHECKPOINTS
  // ============================================================

  void _checkCheckpoints() {
    final ball = _ball;

    if (ball == null) {
      return;
    }

    final point = Offset(
      ball.position.x,
      ball.position.y,
    );

    for (int i = 0;
        i < _checkpointRects.length;
        i++) {
      final checkpointNumber =
          i + 1;

      if (checkpointNumber <=
          _currentCheckpoint) {
        continue;
      }

      if (_checkpointRects[i]
          .contains(point)) {
        _currentCheckpoint =
            checkpointNumber;

        _respawnPosition =
            ball.position.clone();

        // Activación visual.
        for (final component
            in _levelComponents) {
          if (component
                  is CheckpointComponent &&
              component.number ==
                  checkpointNumber) {
            component.activate();
          }
        }

        _publishHud();

        break;
      }
    }
  }

  // ============================================================
  // COMPLETAR
  // ============================================================

  void _completeLevel() {
    final ball = _ball;

    if (ball == null) {
      return;
    }

    _completed = true;

    _velocity = Vector2.zero();

    ball.completed = true;

    _portal?.complete();

    _publishHud();
  }

  // ============================================================
  // PISTA
  // ============================================================

  bool _isBallOnTrack() {
    final ball = _ball;

    if (ball == null) {
      return false;
    }

    final point = Offset(
      ball.position.x,
      ball.position.y,
    );

    for (final rect in _trackRects) {
      final safeRect = rect.deflate(
        _ballRadius * 0.45,
      );

      if (safeRect.contains(point)) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // RESPAWN
  // ============================================================

  void _respawnBall() {
    final ball = _ball;

    if (ball == null) {
      return;
    }

    ball.position =
        _respawnPosition.clone();

    _velocity = Vector2.zero();

    _smoothedAcceleration =
        Vector2.zero();
  }

  // ============================================================
  // REINICIAR
  // ============================================================

  void restartLevel() {
    final ball = _ball;

    if (ball == null) {
      return;
    }

    _elapsedTime = 0;
    _hudAccumulator = 0;

    _currentCheckpoint = 0;

    _completed = false;
    _falling = false;

    _respawnPosition =
        _startPosition.clone();

    ball.position =
        _startPosition.clone();

    ball.scale =
        Vector2.all(1);

    ball.opacity = 1;

    ball.completed = false;

    _portal?.resetPortal();

    for (final component
        in _levelComponents) {
      if (component
          is CheckpointComponent) {
        component.resetCheckpoint();
      }
    }

    _velocity =
        Vector2.zero();

    _smoothedAcceleration =
        Vector2.zero();

    _publishHud();
  }

  // ============================================================
  // HUD
  // ============================================================

  void _publishHud() {
    hud.value = TiltMazeHudState(
      time: _elapsedTime,
      checkpoint:
          _currentCheckpoint,
      totalCheckpoints:
          _checkpointRects.length,
      completed: _completed,
      falling: _falling,
    );
  }

  // ============================================================
  // SENSOR
  // ============================================================

  double _smoothAxis(
    double previous,
    double current,
  ) {
    const double smoothing = 0.15;

    return previous +
        (current - previous) *
            smoothing;
  }

  double _applyDeadZone(
    double value,
  ) {
    if (value.abs() < _deadZone) {
      return 0;
    }

    return value;
  }

  // ============================================================
  // CERRAR
  // ============================================================

  Future<void> close() async {
    if (_closed) {
      return;
    }

    _closed = true;

    await _readingSubscription
        ?.cancel();

    _readingSubscription = null;

    await _accelerometerService
        .dispose();

    currentReading.dispose();

    hud.dispose();
  }

  @override
  void onRemove() {
    unawaited(
      close(),
    );

    super.onRemove();
  }
}

// ============================================================
// BOLA CON GLOW
// ============================================================

class GlowingBallComponent
    extends PositionComponent {
  GlowingBallComponent({
    required double radius,
    required Vector2 position,
    super.priority,
  })  : radius = radius,
        super(
          position: position,
          size: Vector2.all(
            radius * 2,
          ),
          anchor: Anchor.center,
        );

  final double radius;

  double opacity = 1;

  bool completed = false;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = Offset(
      radius,
      radius,
    );

    // Glow grande.
    canvas.drawCircle(
      center,
      radius * 1.65,
      Paint()
        ..color = (completed
                ? TiltMazeGame._goalColor
                : TiltMazeGame._ballColor)
            .withValues(
          alpha: 0.10 * opacity,
        ),
    );

    // Glow medio.
    canvas.drawCircle(
      center,
      radius * 1.30,
      Paint()
        ..color = (completed
                ? TiltMazeGame._goalColor
                : TiltMazeGame._ballColor)
            .withValues(
          alpha: 0.20 * opacity,
        ),
    );

    // Esfera.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader =
            RadialGradient(
          center:
              const Alignment(
            -0.35,
            -0.35,
          ),
          radius: 0.85,
          colors: completed
              ? [
                  Colors.white,
                  TiltMazeGame
                      ._goalColor,
                  const Color(
                    0xFF087A4B,
                  ),
                ]
              : [
                  TiltMazeGame
                      ._ballCoreColor,
                  TiltMazeGame
                      ._ballColor,
                  const Color(
                    0xFF4930A6,
                  ),
                ],
        ).createShader(
          Rect.fromCircle(
            center: center,
            radius: radius,
          ),
        ),
    );

    // Reflejo.
    canvas.drawCircle(
      Offset(
        radius * 0.70,
        radius * 0.65,
      ),
      radius * 0.20,
      Paint()
        ..color =
            Colors.white.withValues(
          alpha: 0.65 * opacity,
        ),
    );
  }
}

// ============================================================
// FONDO DE ESTRELLAS
// ============================================================

class StarFieldComponent
    extends Component
    with HasGameReference<TiltMazeGame> {
  StarFieldComponent({
    super.priority,
  });

  final List<_Star> _stars = [];

  final math.Random _random =
      math.Random(42);

  bool _created = false;

  @override
  void update(double dt) {
    super.update(dt);

    if (!_created &&
        game.size.x > 0 &&
        game.size.y > 0) {
      _createStars();

      _created = true;
    }

    for (final star in _stars) {
      star.y +=
          star.speed * dt;

      if (star.y >
          game.size.y) {
        star.y = 0;
      }
    }
  }

  void _createStars() {
    _stars.clear();

    for (int i = 0;
        i < 75;
        i++) {
      _stars.add(
        _Star(
          x: _random.nextDouble() *
              game.size.x,
          y: _random.nextDouble() *
              game.size.y,
          radius:
              0.5 +
                  _random
                          .nextDouble() *
                      1.4,
          opacity:
              0.20 +
                  _random
                          .nextDouble() *
                      0.55,
          speed:
              2 +
                  _random
                          .nextDouble() *
                      7,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Nebulosa suave.
    canvas.drawCircle(
      Offset(
        game.size.x * 0.15,
        game.size.y * 0.25,
      ),
      150,
      Paint()
        ..shader =
            RadialGradient(
          colors: [
            const Color(
              0xFF483D8B,
            ).withValues(
              alpha: 0.10,
            ),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(
              game.size.x *
                  0.15,
              game.size.y *
                  0.25,
            ),
            radius: 150,
          ),
        ),
    );

    for (final star in _stars) {
      canvas.drawCircle(
        Offset(
          star.x,
          star.y,
        ),
        star.radius,
        Paint()
          ..color =
              Colors.white.withValues(
            alpha:
                star.opacity,
          ),
      );
    }
  }
}

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.speed,
  });

  double x;
  double y;

  final double radius;
  final double opacity;
  final double speed;
}

// ============================================================
// CHECKPOINT
// ============================================================

class CheckpointComponent
    extends PositionComponent {
  CheckpointComponent({
    required Vector2 position,
    required this.number,
    required this.radius,
    super.priority,
  }) : super(
          position: position,
          size: Vector2.all(
            radius * 2,
          ),
          anchor: Anchor.center,
        );

  final int number;
  final double radius;

  bool _active = false;

  double _pulse = 0;

  void activate() {
    _active = true;
    _pulse = 0;
  }

  void resetCheckpoint() {
    _active = false;
    _pulse = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _pulse += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center =
        Offset(radius, radius);

    final color = _active
        ? TiltMazeGame._goalColor
        : TiltMazeGame
            ._checkpointColor;

    final pulse =
        math.sin(
          _pulse * 4,
        ) *
            2.5;

    // Halo.
    canvas.drawCircle(
      center,
      radius + 8 + pulse,
      Paint()
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = 3
        ..color =
            color.withValues(
          alpha: 0.18,
        ),
    );

    // Anillo.
    canvas.drawCircle(
      center,
      radius - 5,
      Paint()
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = 4
        ..color =
            color.withValues(
          alpha: 0.85,
        ),
    );

    // Centro.
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = color,
    );
  }
}

// ============================================================
// PORTAL FINAL
// ============================================================

class GoalPortalComponent
    extends PositionComponent {
  GoalPortalComponent({
    required Vector2 position,
    required this.radius,
    super.priority,
  }) : super(
          position: position,
          size: Vector2.all(
            radius * 2,
          ),
          anchor: Anchor.center,
        );

  final double radius;

  double _rotation = 0;

  bool _completed = false;

  void complete() {
    _completed = true;
  }

  void resetPortal() {
    _completed = false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _rotation += dt * 1.8;

    angle = _rotation;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center =
        Offset(radius, radius);

    // Glow.
    canvas.drawCircle(
      center,
      radius * 1.35,
      Paint()
        ..color = TiltMazeGame
            ._goalColor
            .withValues(
          alpha:
              _completed
                  ? 0.25
                  : 0.10,
        ),
    );

    // Anillo externo.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = TiltMazeGame
            ._goalColor,
    );

    // Anillo interior.
    canvas.drawCircle(
      center,
      radius * 0.63,
      Paint()
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = 3
        ..color =
            Colors.white.withValues(
          alpha: 0.75,
        ),
    );

    // Núcleo.
    canvas.drawCircle(
      center,
      radius * 0.30,
      Paint()
        ..color = TiltMazeGame
            ._goalColor
            .withValues(
          alpha:
              _completed
                  ? 0.95
                  : 0.38,
        ),
    );

    // Marcas alrededor.
    for (int i = 0;
        i < 4;
        i++) {
      final angle =
          (math.pi / 2) * i;

      final start = Offset(
        center.dx +
            math.cos(angle) *
                radius *
                0.78,
        center.dy +
            math.sin(angle) *
                radius *
                0.78,
      );

      final end = Offset(
        center.dx +
            math.cos(angle) *
                radius *
                1.08,
        center.dy +
            math.sin(angle) *
                radius *
                1.08,
      );

      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = 3
          ..strokeCap =
              StrokeCap.round
          ..color = TiltMazeGame
              ._goalColor,
      );
    }
  }
}

// ============================================================
// PLATAFORMA DE INICIO
// ============================================================

class StartPlatformComponent
    extends PositionComponent {
  StartPlatformComponent({
    required Vector2 position,
    required this.radius,
    super.priority,
  }) : super(
          position: position,
          size: Vector2.all(
            radius * 2,
          ),
          anchor: Anchor.center,
        );

  final double radius;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center =
        Offset(radius, radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = TiltMazeGame
            ._startColor
            .withValues(
          alpha: 0.15,
        ),
    );

    canvas.drawCircle(
      center,
      radius - 4,
      Paint()
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = TiltMazeGame
            ._startColor
            .withValues(
          alpha: 0.75,
        ),
    );

    canvas.drawCircle(
      center,
      5,
      Paint()
        ..color = TiltMazeGame
            ._startColor,
    );
  }
}

// ============================================================
// ZONA DE HIELO
// ============================================================

class IceZoneComponent extends PositionComponent {
  IceZoneComponent({
    required Vector2 position,
    required Vector2 size,
    super.priority,
  }) : super(
          position: position,
          size: size,
        );

  double _animationTime = 0;

  @override
  void update(double dt) {
    super.update(dt);

    _animationTime += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rect = Rect.fromLTWH(
      0,
      0,
      size.x,
      size.y,
    );

    // Base azul transparente.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(12),
      ),
      Paint()
        ..color = const Color(
          0xFF49C6FF,
        ).withValues(
          alpha: 0.24,
        ),
    );

    // Brillo superior.
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(
          alpha: 0.35,
        ),
        const Color(
          0xFF61DAFF,
        ).withValues(
          alpha: 0.15,
        ),
        const Color(
          0xFF247DFF,
        ).withValues(
          alpha: 0.20,
        ),
      ],
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(3),
        const Radius.circular(10),
      ),
      Paint()
        ..shader =
            gradient.createShader(
          rect,
        ),
    );

    // Líneas de hielo.
    final linePaint = Paint()
      ..color =
          Colors.white.withValues(
        alpha: 0.22,
      )
      ..strokeWidth = 1.5;

    final offset =
        (_animationTime * 12) % 30;

    for (double x = -30 + offset;
        x < size.x + 30;
        x += 30) {
      canvas.drawLine(
        Offset(
          x,
          0,
        ),
        Offset(
          x + 25,
          size.y,
        ),
        linePaint,
      );
    }
  }
}

// ============================================================
// LÁSER MÓVIL
// ============================================================

class MovingLaserComponent
    extends PositionComponent {
  MovingLaserComponent({
  required Vector2 centerPosition,
  required this.movementWidth,
  required this.laserLength,
  required this.speed,
  required this.movementFactor,
  super.priority,
}) : super(
          position:
              centerPosition.clone(),
          size: Vector2(
            movementWidth,
            laserLength,
          ),
          anchor:
              Anchor.center,
        );

  final double movementWidth;
  final double laserLength;

  final double speed;
  final double movementFactor;

  double _time = 0;

  double _laserX = 0;

  static const double _laserThickness = 8;

  @override
  void update(double dt) {
    super.update(dt);

    _time += dt;

    // Movimiento de izquierda a derecha.
    final normalized = math.sin(
      _time * speed,
    );

    _laserX =
        normalized *
        movementWidth *
        movementFactor;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final centerX =
        size.x / 2 + _laserX;

    final start = Offset(
      centerX,
      4,
    );

    final end = Offset(
      centerX,
      size.y - 4,
    );

    // Glow grande.
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color =
            const Color(
          0xFFFF1744,
        ).withValues(
          alpha: 0.18,
        )
        ..strokeWidth = 20
        ..strokeCap =
            StrokeCap.round,
    );

    // Glow medio.
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color =
            const Color(
          0xFFFF1744,
        ).withValues(
          alpha: 0.45,
        )
        ..strokeWidth = 13
        ..strokeCap =
            StrokeCap.round,
    );

    // Núcleo.
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color =
            Colors.white
        ..strokeWidth =
            _laserThickness
        ..strokeCap =
            StrokeCap.round,
    );

    // Emisores.
    canvas.drawCircle(
      start,
      9,
      Paint()
        ..color =
            const Color(
          0xFFFF1744,
        ),
    );

    canvas.drawCircle(
      end,
      9,
      Paint()
        ..color =
            const Color(
          0xFFFF1744,
        ),
    );
  }

  bool collidesWithBall(
    Vector2 ballPosition,
    double ballRadius,
  ) {
    // Convertimos la posición global del láser.
    final laserGlobalX =
        position.x -
            size.x / 2 +
            size.x / 2 +
            _laserX;

    final laserTop =
        position.y -
            size.y / 2;

    final laserBottom =
        position.y +
            size.y / 2;

    final horizontalDistance =
        (ballPosition.x -
                laserGlobalX)
            .abs();

    final verticalInside =
        ballPosition.y +
                    ballRadius >
                laserTop &&
            ballPosition.y -
                    ballRadius <
                laserBottom;

    return horizontalDistance <
            ballRadius +
                _laserThickness /
                    2 &&
        verticalInside;
  }
}