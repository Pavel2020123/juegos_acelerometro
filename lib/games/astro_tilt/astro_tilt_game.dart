import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/sensors/accelerometer_service.dart';
import 'astro_tilt_level.dart';

enum AstroTiltPhase {
  calibrating,
  countdown,
  playing,
  paused,
  victory,
  defeated,
}

enum AstroEnemyKind { basic, zigzag, fast }

enum AstroPowerUpKind {
  shield,
  doubleShot,
  repair,
  drone,
  tripleShot,
  missiles,
  energy,
}

enum AstroProjectileKind { normal, drone, missile }

enum AstroAudioEvent { mainShot, droneShot, victory, defeat }

class AstroDrone {
  AstroDrone({
    required this.position,
    required this.side,
    required this.remaining,
  });

  Offset position;
  final int side;
  double remaining;
  double fireTimer = 0;
  double get opacity => (remaining / 0.45).clamp(0.0, 1.0);
}

class AstroEnemy {
  AstroEnemy({
    required this.position,
    required this.kind,
    required this.radius,
    required this.speed,
  });

  Offset position;
  final AstroEnemyKind kind;
  final double radius;
  final double speed;
  double age = 0;
  double health = 1;
}

class AstroProjectile {
  AstroProjectile({
    required this.position,
    required this.velocity,
    required this.radius,
    this.fromPlayer = true,
    this.kind = AstroProjectileKind.normal,
    this.damage = 1,
  });

  Offset position;
  Offset velocity;
  final double radius;
  final bool fromPlayer;
  final AstroProjectileKind kind;
  final double damage;
  double age = 0;
}

class AstroMeteor {
  AstroMeteor({
    required this.position,
    required this.radius,
    required this.speed,
    required this.rotationSpeed,
  });

  Offset position;
  final double radius;
  final double speed;
  final double rotationSpeed;
  double rotation = 0;
  double health = 1;
}

class AstroPowerUp {
  AstroPowerUp({required this.position, required this.kind});

  Offset position;
  final AstroPowerUpKind kind;
}

class AstroExplosion {
  AstroExplosion({required this.position, required this.color});

  final Offset position;
  final int color;
  double age = 0;
}

class AstroBoss {
  AstroBoss({
    required this.position,
    required this.radius,
    required this.maxHealth,
  }) : health = maxHealth;

  Offset position;
  final double radius;
  final int maxHealth;
  num health;
}

class AstroTiltGame extends ChangeNotifier {
  AstroTiltGame({
    required this.level,
    AccelerometerService? accelerometerService,
    this.onAudioEvent,
  }) : _accelerometerService = accelerometerService ?? AccelerometerService(),
       health = level.shipHealth {
    start();
  }

  final AstroTiltLevel level;
  final AccelerometerService _accelerometerService;
  final void Function(AstroAudioEvent)? onAudioEvent;

  final List<AstroEnemy> enemies = [];
  final List<AstroProjectile> projectiles = [];
  final List<AstroMeteor> meteors = [];
  final List<AstroPowerUp> powerUps = [];
  final List<AstroExplosion> explosions = [];
  final List<AstroDrone> drones = [];

  StreamSubscription<AccelerometerReading>? _subscription;
  AccelerometerReading? _lastReading;
  Offset _filteredInput = Offset.zero;
  Offset _velocity = Offset.zero;
  Offset _touchInput = Offset.zero;
  Offset _neutral = Offset.zero;
  Offset _playerPosition = Offset.zero;
  Size _viewport = Size.zero;
  AstroBoss? boss;
  AstroTiltPhase _phase = AstroTiltPhase.calibrating;
  AstroTiltPhase? _phaseBeforePause;
  bool _closed = false;
  bool _touchMode = false;
  bool _sensorAvailable = false;
  Object? _sensorError;
  double _elapsed = 0;
  double _countdown = 3;
  double _fireTimer = 0;
  double _enemyTimer = 0;
  double _meteorTimer = 0;
  double _powerUpTimer = 0;
  double _bossShotTimer = 0;
  double _invulnerability = 0;
  double _shieldTime = 0;
  double _doubleShotTime = 0;
  double _tripleShotTime = 0;
  double _missileTime = 0;
  double _missileTimer = 0;
  double _specialEnergy = 0;
  double _pulseTime = 0;
  double _damageFlash = 0;
  double _survivalPoints = 0;
  int _bonusPoints = 0;
  double health;
  int _score = 0;
  int _enemiesDestroyed = 0;
  int _meteorsDestroyed = 0;
  int _streak = 0;
  int _combo = 1;
  int _maxCombo = 1;
  bool _bossDefeated = false;
  bool _bossSpawned = false;
  bool _bossShotPhaseTwo = false;
  math.Random _random = math.Random(1);

  AstroTiltPhase get phase => _phase;
  Offset get playerPosition => _playerPosition;
  Offset get velocity => _velocity;
  Size get viewport => _viewport;
  double get elapsed => _elapsed;
  double get remaining => math.max(0, level.duration - _elapsed);
  double get countdown => _countdown;
  int get score => _score;
  int get enemiesDestroyed => _enemiesDestroyed;
  int get meteorsDestroyed => _meteorsDestroyed;
  int get combo => _combo;
  int get maxCombo => _maxCombo;
  double get healthFraction => (health / level.shipHealth).clamp(0.0, 1.0);
  double get invulnerability => _invulnerability;
  double get damageFlash => _damageFlash;
  bool get shieldActive => _shieldTime > 0;
  double get shieldTime => _shieldTime;
  bool get doubleShotActive => _doubleShotTime > 0;
  double get doubleShotTime => _doubleShotTime;
  double get tripleShotTime => _tripleShotTime;
  double get missileTime => _missileTime;
  double get specialEnergy => _specialEnergy;
  bool get specialReady => _specialEnergy >= 100;
  double get pulseTime => _pulseTime;
  bool get sensorAvailable => _sensorAvailable;
  Object? get sensorError => _sensorError;
  bool get touchMode => _touchMode;
  bool get bossDefeated => _bossDefeated;
  bool get bossSpawned => _bossSpawned;
  bool get bossPhaseTwo => _bossShotPhaseTwo;
  bool get isClosed => _closed;
  int get stars => _starsForResult();
  String get victoryMessage => switch (level.id) {
    1 => '¡PATRULLA COMPLETADA!',
    2 => '¡CAMPO SUPERADO!',
    _ => '¡ASTROTILT COMPLETADO!',
  };

  double get _playTop => math.min(160, _viewport.height * 0.34);
  double get _playBottom => math.max(_playTop + 160, _viewport.height - 34);
  double get _shipRadius => (_viewport.shortestSide * 0.045).clamp(18.0, 25.0);
  double get playerHitRadius => _shipRadius * 0.57;

  void start() {
    if (_closed || _subscription != null) return;
    _subscription = _accelerometerService.readings.listen(
      _onReading,
      onError: (Object error) {
        if (_closed) return;
        _sensorAvailable = false;
        _sensorError = error;
        _filteredInput = Offset.zero;
        notifyListeners();
      },
    );
    _accelerometerService.start();
  }

  void setViewport(Size size) {
    if (size.width <= 0 || size.height <= 0 || size == _viewport) return;
    _viewport = size;
    if (_playerPosition == Offset.zero) {
      _playerPosition = Offset(size.width / 2, _playBottom - 78);
    } else {
      _playerPosition = _clampPlayer(_playerPosition);
    }
  }

  bool calibrate() {
    if (_closed ||
        _phase != AstroTiltPhase.calibrating ||
        (!_touchMode && _lastReading == null)) {
      return false;
    }
    if (!_touchMode) {
      _neutral = Offset(_lastReading!.x, _lastReading!.y);
    }
    _filteredInput = Offset.zero;
    _velocity = Offset.zero;
    _countdown = 3;
    _phase = AstroTiltPhase.countdown;
    notifyListeners();
    return true;
  }

  void setTouchMode(bool enabled) {
    if (_closed || enabled == _touchMode) return;
    _touchMode = enabled;
    _touchInput = Offset.zero;
    _filteredInput = Offset.zero;
    _velocity = Offset.zero;
    notifyListeners();
  }

  void setTouchInput(Offset input) {
    if (_closed || !_touchMode || _phase != AstroTiltPhase.playing) return;
    _touchInput = Offset(input.dx.clamp(-1.0, 1.0), input.dy.clamp(-1.0, 1.0));
  }

  void pause() {
    if (_closed || _phase == AstroTiltPhase.paused) return;
    if (_phase == AstroTiltPhase.victory || _phase == AstroTiltPhase.defeated) {
      return;
    }
    _phaseBeforePause = _phase;
    _phase = AstroTiltPhase.paused;
    _touchInput = Offset.zero;
    _filteredInput = Offset.zero;
    _velocity = Offset.zero;
    notifyListeners();
  }

  void resume() {
    if (_closed || _phase != AstroTiltPhase.paused) return;
    _phase = _phaseBeforePause ?? AstroTiltPhase.playing;
    _phaseBeforePause = null;
    _filteredInput = Offset.zero;
    _velocity = Offset.zero;
    notifyListeners();
  }

  void restart() {
    if (_closed) return;
    enemies.clear();
    projectiles.clear();
    meteors.clear();
    powerUps.clear();
    explosions.clear();
    drones.clear();
    boss = null;
    _filteredInput = Offset.zero;
    _velocity = Offset.zero;
    _touchInput = Offset.zero;
    _elapsed = 0;
    _countdown = 3;
    _fireTimer = 0;
    _enemyTimer = 0;
    _meteorTimer = 0;
    _powerUpTimer = 0;
    _bossShotTimer = 0;
    _invulnerability = 0;
    _shieldTime = 0;
    _doubleShotTime = 0;
    _tripleShotTime = 0;
    _missileTime = 0;
    _missileTimer = 0;
    _specialEnergy = 0;
    _pulseTime = 0;
    _damageFlash = 0;
    _survivalPoints = 0;
    _bonusPoints = 0;
    health = level.shipHealth;
    _score = 0;
    _enemiesDestroyed = 0;
    _meteorsDestroyed = 0;
    _streak = 0;
    _combo = 1;
    _maxCombo = 1;
    _bossDefeated = false;
    _bossSpawned = false;
    _bossShotPhaseTwo = false;
    _phaseBeforePause = null;
    _phase = AstroTiltPhase.calibrating;
    _playerPosition = _viewport == Size.zero
        ? Offset.zero
        : Offset(_viewport.width / 2, _playBottom - 78);
    _random = math.Random(level.id * 8191);
    notifyListeners();
  }

  void update(double delta) {
    if (_closed || delta <= 0) return;
    var remainingDelta = delta;
    var changed = false;
    while (remainingDelta > 0) {
      final dt = math.min(remainingDelta, 0.05);
      remainingDelta -= dt;
      if (_phase == AstroTiltPhase.countdown) {
        _countdown -= dt;
        if (_countdown <= 0) {
          _phase = AstroTiltPhase.playing;
          _countdown = 0;
        }
        changed = true;
        continue;
      }
      if (_phase != AstroTiltPhase.playing || _viewport == Size.zero) break;
      _updatePlaying(dt);
      changed = true;
      if (_phase == AstroTiltPhase.victory ||
          _phase == AstroTiltPhase.defeated) {
        break;
      }
    }
    if (changed) notifyListeners();
  }

  void _updatePlaying(double dt) {
    _elapsed += dt;
    _survivalPoints += dt * 10;
    _score = _survivalPoints.floor() + _bonusPoints;
    _invulnerability = math.max(0, _invulnerability - dt);
    _shieldTime = math.max(0, _shieldTime - dt);
    _doubleShotTime = math.max(0, _doubleShotTime - dt);
    _tripleShotTime = math.max(0, _tripleShotTime - dt);
    _missileTime = math.max(0, _missileTime - dt);
    _pulseTime = math.max(0, _pulseTime - dt);
    _damageFlash = math.max(0, _damageFlash - dt);

    _movePlayer(dt);
    _updateDrones(dt);
    _updateSpawning(dt);
    _updateProjectiles(dt);
    _updateEnemies(dt);
    _updateMeteors(dt);
    _updatePowerUps(dt);
    _updateBoss(dt);
    _updateExplosions(dt);
    _resolvePlayerCollisions();
    _spawnBossIfReady();

    if (health <= 0) {
      _phase = AstroTiltPhase.defeated;
      onAudioEvent?.call(AstroAudioEvent.defeat);
    } else if (_elapsed >= level.duration &&
        (!level.hasBoss || _bossDefeated)) {
      _phase = AstroTiltPhase.victory;
      onAudioEvent?.call(AstroAudioEvent.victory);
    }
  }

  void damagePlayer([double amount = 24]) {
    if (_closed || _phase != AstroTiltPhase.playing || _invulnerability > 0) {
      return;
    }
    if (_shieldTime > 0) {
      _shieldTime = 0;
      _invulnerability = 0.45;
      notifyListeners();
      return;
    }
    health = math.max(0, health - amount);
    _invulnerability = 1.15;
    _damageFlash = 0.32;
    _streak = 0;
    _combo = 1;
    if (health <= 0) {
      _phase = AstroTiltPhase.defeated;
      onAudioEvent?.call(AstroAudioEvent.defeat);
    }
    notifyListeners();
  }

  void spawnEnemy({
    required AstroEnemyKind kind,
    Offset? position,
    double? speed,
    double? radius,
  }) {
    if (_closed) return;
    final size = _enemyRadius(kind);
    enemies.add(
      AstroEnemy(
        position:
            position ??
            Offset(
              _random.nextDouble() * math.max(1, _viewport.width - size * 2) +
                  size,
              _playTop + size,
            ),
        kind: kind,
        radius: radius ?? size,
        speed: speed ?? level.enemySpeed * _enemySpeedFactor(kind),
      ),
    );
  }

  void spawnMeteor({Offset? position, double? speed, double? radius}) {
    if (_closed) return;
    final size = radius ?? (_viewport.shortestSide * 0.035).clamp(13.0, 22.0);
    meteors.add(
      AstroMeteor(
        position:
            position ??
            Offset(
              _random.nextDouble() * math.max(1, _viewport.width - size * 2) +
                  size,
              _playTop - size,
            ),
        radius: size,
        speed: speed ?? level.enemySpeed * 0.72,
        rotationSpeed: _random.nextDouble() * 2.6 - 1.3,
      ),
    );
  }

  void spawnPowerUp({required AstroPowerUpKind kind, Offset? position}) {
    if (_closed) return;
    powerUps.add(
      AstroPowerUp(
        position: position ?? Offset(_viewport.width / 2, _playTop + 20),
        kind: kind,
      ),
    );
  }

  void spawnBoss() {
    if (_closed || !level.hasBoss || _bossSpawned || _viewport == Size.zero) {
      return;
    }
    _bossSpawned = true;
    boss = AstroBoss(
      position: Offset(_viewport.width / 2, _playTop + 58),
      radius: (_viewport.width * 0.19).clamp(47.0, 72.0),
      maxHealth: level.bossHealth,
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _accelerometerService.dispose();
    super.dispose();
  }

  void _onReading(AccelerometerReading reading) {
    if (_closed) return;
    _lastReading = reading;
    _sensorAvailable = true;
    _sensorError = null;
    if (_touchMode || _phase == AstroTiltPhase.paused) return;
    final x = -(reading.x - _neutral.dx);
    final y = reading.y - _neutral.dy;
    const deadZone = 0.25;
    const fullTilt = 2.4;
    double applyDeadZone(double value) {
      final magnitude = value.abs();
      if (magnitude <= deadZone) return 0;
      final scaled = ((magnitude - deadZone) / (fullTilt - deadZone)).clamp(
        0.0,
        1.0,
      );
      return value.sign * scaled;
    }

    _filteredInput = Offset(
      _filteredInput.dx + (applyDeadZone(x) - _filteredInput.dx) * 0.22,
      _filteredInput.dy + (applyDeadZone(y) - _filteredInput.dy) * 0.22,
    );
    notifyListeners();
  }

  void _movePlayer(double dt) {
    final input = _touchMode ? _touchInput : _filteredInput;
    _velocity = Offset(
      (_velocity.dx + input.dx * level.sensitivity * dt) * math.exp(-3.0 * dt),
      (_velocity.dy + input.dy * level.sensitivity * dt) * math.exp(-3.0 * dt),
    );
    final speed = _velocity.distance;
    if (speed > level.maxSpeed) {
      _velocity = _velocity / speed * level.maxSpeed;
    }
    _playerPosition = _clampPlayer(_playerPosition + _velocity * dt);
  }

  Offset _clampPlayer(Offset position) => Offset(
    position.dx.clamp(
      _shipRadius,
      math.max(_shipRadius, _viewport.width - _shipRadius),
    ),
    position.dy.clamp(
      _playTop + _shipRadius,
      math.max(_playTop + _shipRadius, _playBottom - _shipRadius),
    ),
  );

  void _updateSpawning(double dt) {
    _fireTimer += dt;
    while (_fireTimer >= level.autoFireInterval) {
      _fireTimer -= level.autoFireInterval;
      _fire();
    }

    _enemyTimer += dt;
    if (_enemyTimer >= level.enemySpawnInterval && enemies.length < 7) {
      _enemyTimer -= level.enemySpawnInterval;
      final kind = _nextEnemyKind();
      spawnEnemy(kind: kind);
    }

    _meteorTimer += dt;
    if (_meteorTimer >= level.meteorSpawnInterval && meteors.length < 5) {
      _meteorTimer -= level.meteorSpawnInterval;
      spawnMeteor();
    }

    if (level.powerUpInterval > 0) {
      _powerUpTimer += dt;
      if (_powerUpTimer >= level.powerUpInterval && powerUps.length < 2) {
        _powerUpTimer -= level.powerUpInterval;
        final kinds = level.id == 1
            ? const [
                AstroPowerUpKind.shield,
                AstroPowerUpKind.repair,
                AstroPowerUpKind.doubleShot,
              ]
            : [
                AstroPowerUpKind.shield,
                AstroPowerUpKind.repair,
                AstroPowerUpKind.doubleShot,
                AstroPowerUpKind.drone,
                if (level.tripleShotEnabled) AstroPowerUpKind.tripleShot,
                if (level.missilesEnabled) AstroPowerUpKind.missiles,
                AstroPowerUpKind.energy,
              ];
        final kind = kinds[_random.nextInt(kinds.length)];
        spawnPowerUp(kind: kind);
      }
    }
  }

  AstroEnemyKind _nextEnemyKind() {
    final roll = _random.nextDouble();
    if (level.id == 1) {
      return roll < 0.2 ? AstroEnemyKind.zigzag : AstroEnemyKind.basic;
    }
    if (roll < 0.28) return AstroEnemyKind.fast;
    if (roll < 0.62) return AstroEnemyKind.zigzag;
    return AstroEnemyKind.basic;
  }

  void _fire() {
    final origin = Offset(_playerPosition.dx, _playerPosition.dy - _shipRadius);
    if (_tripleShotTime > 0) {
      for (final horizontal in [-90.0, 0.0, 90.0]) {
        projectiles.add(
          AstroProjectile(
            position: origin,
            velocity: Offset(horizontal, -440),
            radius: 4,
          ),
        );
      }
    } else if (_doubleShotTime > 0) {
      projectiles
        ..add(
          AstroProjectile(
            position: origin + const Offset(-9, 0),
            velocity: const Offset(0, -440),
            radius: 4,
          ),
        )
        ..add(
          AstroProjectile(
            position: origin + const Offset(9, 0),
            velocity: const Offset(0, -440),
            radius: 4,
          ),
        );
    } else {
      projectiles.add(
        AstroProjectile(
          position: origin,
          velocity: const Offset(0, -440),
          radius: 4.5,
        ),
      );
    }
    onAudioEvent?.call(AstroAudioEvent.mainShot);
  }

  void _updateDrones(double dt) {
    for (final drone in drones) {
      drone.remaining -= dt;
      final target = _clampPlayer(
        _playerPosition + Offset(drone.side * 43, 12),
      );
      drone.position += (target - drone.position) * math.min(1, dt * 7);
      drone.fireTimer += dt;
      if (drone.remaining > 0 && drone.fireTimer >= 0.66) {
        drone.fireTimer -= 0.66;
        projectiles.add(
          AstroProjectile(
            position: drone.position + const Offset(0, -12),
            velocity: const Offset(0, -390),
            radius: 3,
            kind: AstroProjectileKind.drone,
            damage: 0.45,
          ),
        );
        onAudioEvent?.call(AstroAudioEvent.droneShot);
      }
    }
    drones.removeWhere((drone) => drone.remaining <= 0);
    if (_missileTime > 0) {
      _missileTimer += dt;
      if (_missileTimer >= 2.2) {
        _missileTimer -= 2.2;
        projectiles.add(
          AstroProjectile(
            position: _playerPosition + Offset(0, -_shipRadius),
            velocity: const Offset(0, -280),
            radius: 5,
            kind: AstroProjectileKind.missile,
            damage: 2.2,
          ),
        );
      }
    }
  }

  Offset? _missileTarget(Offset from) {
    Offset? target;
    var nearest = double.infinity;
    for (final enemy in enemies) {
      final distance = (enemy.position - from).distance;
      if (distance < nearest) {
        nearest = distance;
        target = enemy.position;
      }
    }
    if (boss case final currentBoss?) {
      final distance = (currentBoss.position - from).distance;
      if (distance < nearest) target = currentBoss.position;
    }
    return target;
  }

  void _updateProjectiles(double dt) {
    for (final projectile in projectiles) {
      projectile.age += dt;
      if (projectile.kind == AstroProjectileKind.missile) {
        final target = _missileTarget(projectile.position);
        if (target != null) {
          final difference = target - projectile.position;
          if (difference.distance > 0) {
            final desired = difference / difference.distance * 300;
            projectile.velocity +=
                (desired - projectile.velocity) * math.min(1, dt * 3.5);
          }
        }
      }
      projectile.position += projectile.velocity * dt;
    }
    projectiles.removeWhere(
      (projectile) =>
          projectile.position.dy < _playTop - 45 ||
          projectile.position.dy > _playBottom + 45 ||
          projectile.position.dx < -45 ||
          projectile.position.dx > _viewport.width + 45 ||
          (projectile.kind == AstroProjectileKind.missile &&
              projectile.age > 2.8),
    );
  }

  void _updateEnemies(double dt) {
    for (final enemy in enemies) {
      enemy.age += dt;
      final x = switch (enemy.kind) {
        AstroEnemyKind.zigzag =>
          enemy.position.dx + math.sin(enemy.age * 3.1) * 34 * dt,
        _ => enemy.position.dx,
      };
      enemy.position = Offset(
        x.clamp(
          enemy.radius,
          math.max(enemy.radius, _viewport.width - enemy.radius),
        ),
        enemy.position.dy + enemy.speed * dt,
      );
    }
    enemies.removeWhere(
      (enemy) => enemy.position.dy > _playBottom + enemy.radius,
    );
  }

  void _updateMeteors(double dt) {
    for (final meteor in meteors) {
      meteor.position = Offset(
        meteor.position.dx,
        meteor.position.dy + meteor.speed * dt,
      );
      meteor.rotation += meteor.rotationSpeed * dt;
    }
    meteors.removeWhere(
      (meteor) => meteor.position.dy > _playBottom + meteor.radius,
    );
  }

  void _updatePowerUps(double dt) {
    for (final powerUp in powerUps) {
      powerUp.position += Offset(0, 48 * dt);
    }
    powerUps.removeWhere((powerUp) => powerUp.position.dy > _playBottom + 20);
  }

  void _updateBoss(double dt) {
    final currentBoss = boss;
    if (currentBoss == null) return;
    final phaseTwo = currentBoss.health <= currentBoss.maxHealth / 2;
    _bossShotPhaseTwo = phaseTwo;
    final wave = math.sin(_elapsed * (phaseTwo ? 1.1 : 0.72));
    currentBoss.position = Offset(
      (_viewport.width / 2 + wave * math.max(0, _viewport.width * 0.32)).clamp(
        currentBoss.radius,
        _viewport.width - currentBoss.radius,
      ),
      _playTop + 58 + math.sin(_elapsed * 1.7) * 8,
    );
    _bossShotTimer += dt;
    final interval = phaseTwo
        ? level.enemyShotInterval * 0.78
        : level.enemyShotInterval;
    if (_bossShotTimer >= interval) {
      _bossShotTimer -= interval;
      _fireBossShot(currentBoss, phaseTwo);
    }
  }

  void _fireBossShot(AstroBoss currentBoss, bool phaseTwo) {
    final target = _playerPosition - currentBoss.position;
    final direction = target.distance == 0
        ? const Offset(0, 1)
        : target / target.distance;
    const speed = 190.0;
    projectiles.add(
      AstroProjectile(
        position: currentBoss.position + Offset(0, currentBoss.radius * 0.55),
        velocity: direction * speed,
        radius: 6,
        fromPlayer: false,
      ),
    );
    if (phaseTwo) {
      for (final side in [-1.0, 1.0]) {
        final angled = Offset(direction.dx + side * 0.28, direction.dy);
        projectiles.add(
          AstroProjectile(
            position:
                currentBoss.position +
                Offset(side * 14, currentBoss.radius * 0.5),
            velocity: angled / angled.distance * speed,
            radius: 5,
            fromPlayer: false,
          ),
        );
      }
    }
  }

  void _updateExplosions(double dt) {
    for (final explosion in explosions) {
      explosion.age += dt;
    }
    explosions.removeWhere((explosion) => explosion.age >= 0.5);
  }

  void _resolvePlayerCollisions() {
    for (
      var bulletIndex = projectiles.length - 1;
      bulletIndex >= 0;
      bulletIndex--
    ) {
      final bullet = projectiles[bulletIndex];
      if (!bullet.fromPlayer) continue;
      var hit = false;
      for (var enemyIndex = enemies.length - 1; enemyIndex >= 0; enemyIndex--) {
        final enemy = enemies[enemyIndex];
        if (_overlaps(
          bullet.position,
          bullet.radius,
          enemy.position,
          enemy.radius * 0.72,
        )) {
          projectiles.removeAt(bulletIndex);
          enemy.health -= bullet.damage;
          if (enemy.health <= 0) {
            enemies.removeAt(enemyIndex);
            _destroyEnemy(enemy);
          }
          hit = true;
          break;
        }
      }
      if (hit) continue;

      for (
        var meteorIndex = meteors.length - 1;
        meteorIndex >= 0;
        meteorIndex--
      ) {
        final meteor = meteors[meteorIndex];
        if (_overlaps(
          bullet.position,
          bullet.radius,
          meteor.position,
          meteor.radius * 0.75,
        )) {
          projectiles.removeAt(bulletIndex);
          meteor.health -= bullet.damage;
          if (meteor.health <= 0) {
            meteors.removeAt(meteorIndex);
            _meteorsDestroyed++;
            _awardPoints(55);
            _addExplosion(meteor.position, 0xFFFFA34F);
          }
          hit = true;
          break;
        }
      }
      if (hit) continue;

      final currentBoss = boss;
      if (currentBoss != null &&
          _overlaps(
            bullet.position,
            bullet.radius,
            currentBoss.position,
            currentBoss.radius * 0.76,
          )) {
        projectiles.removeAt(bulletIndex);
        currentBoss.health -= bullet.damage;
        _finishBossIfDefeated(currentBoss);
      }
    }

    for (var index = projectiles.length - 1; index >= 0; index--) {
      final projectile = projectiles[index];
      if (!projectile.fromPlayer &&
          _overlaps(
            projectile.position,
            projectile.radius,
            _playerPosition,
            playerHitRadius * 0.78,
          )) {
        projectiles.removeAt(index);
        damagePlayer(20);
      }
    }

    for (var index = enemies.length - 1; index >= 0; index--) {
      final enemy = enemies[index];
      if (_overlaps(
        enemy.position,
        enemy.radius * 0.67,
        _playerPosition,
        playerHitRadius * 0.82,
      )) {
        enemies.removeAt(index);
        _addExplosion(enemy.position, 0xFFFF8D67);
        damagePlayer(25);
      }
    }
    for (var index = meteors.length - 1; index >= 0; index--) {
      final meteor = meteors[index];
      if (_overlaps(
        meteor.position,
        meteor.radius * 0.76,
        _playerPosition,
        playerHitRadius * 0.84,
      )) {
        meteors.removeAt(index);
        _addExplosion(meteor.position, 0xFFFFA34F);
        damagePlayer(28);
      }
    }
    for (var index = powerUps.length - 1; index >= 0; index--) {
      final powerUp = powerUps[index];
      if (!_overlaps(powerUp.position, 13, _playerPosition, playerHitRadius)) {
        continue;
      }
      powerUps.removeAt(index);
      _collectPowerUp(powerUp.kind);
    }
  }

  void _destroyEnemy(AstroEnemy enemy) {
    _enemiesDestroyed++;
    _streak++;
    _combo = math.min(4, 1 + _streak ~/ 2);
    _maxCombo = math.max(_maxCombo, _combo);
    final base = switch (enemy.kind) {
      AstroEnemyKind.basic => 100,
      AstroEnemyKind.zigzag => 150,
      AstroEnemyKind.fast => 200,
    };
    _awardPoints(base * _combo);
    if (level.specialGain > 0) {
      _specialEnergy = math.min(
        100,
        _specialEnergy + level.specialGain + (_combo - 1) * 2,
      );
    }
    _addExplosion(enemy.position, 0xFF63DDF2);
  }

  void _collectPowerUp(AstroPowerUpKind kind) {
    switch (kind) {
      case AstroPowerUpKind.shield:
        _shieldTime = 9;
      case AstroPowerUpKind.doubleShot:
        _doubleShotTime = 8;
      case AstroPowerUpKind.repair:
        health = math.min(level.shipHealth, health + 24);
      case AstroPowerUpKind.drone:
        if (level.maxDrones > 0) {
          final side = drones.isEmpty ? -1 : 1;
          if (drones.length < level.maxDrones) {
            final position = _clampPlayer(
              _playerPosition + Offset(side * 43, 12),
            );
            drones.add(
              AstroDrone(
                position: position,
                side: side,
                remaining: level.droneDuration,
              ),
            );
            _addExplosion(position, 0xFF6BE5F4);
          } else {
            drones.first.remaining = level.droneDuration;
          }
        }
      case AstroPowerUpKind.tripleShot:
        if (level.tripleShotEnabled) {
          _tripleShotTime = 8;
          _doubleShotTime = 0;
        }
      case AstroPowerUpKind.missiles:
        if (level.missilesEnabled) _missileTime = 8;
      case AstroPowerUpKind.energy:
        if (level.specialGain > 0) {
          _specialEnergy = math.min(100, _specialEnergy + 30);
        }
    }
    _addExplosion(_playerPosition, 0xFFFFDF8B);
    _awardPoints(40);
  }

  bool activateSpecial() {
    if (_closed || _phase != AstroTiltPhase.playing || !specialReady) {
      return false;
    }
    _specialEnergy = 0;
    _pulseTime = 0.45;
    projectiles.removeWhere(
      (projectile) =>
          !projectile.fromPlayer &&
          (projectile.position - _playerPosition).distance <
              _viewport.shortestSide * 0.8,
    );
    for (var index = enemies.length - 1; index >= 0; index--) {
      final enemy = enemies[index];
      enemy.health -= 1.5;
      if (enemy.health <= 0) {
        enemies.removeAt(index);
        _destroyEnemy(enemy);
      }
    }
    if (boss case final currentBoss?) {
      currentBoss.health -= 3;
      _finishBossIfDefeated(currentBoss);
    }
    notifyListeners();
    return true;
  }

  void _finishBossIfDefeated(AstroBoss currentBoss) {
    if (currentBoss.health > 0 || boss != currentBoss) return;
    _bossDefeated = true;
    _awardPoints(1200);
    _addExplosion(currentBoss.position, 0xFF9A6BFF);
    boss = null;
  }

  void _spawnBossIfReady() {
    if (level.hasBoss &&
        !_bossSpawned &&
        _elapsed >= level.duration - level.bossWindow) {
      spawnBoss();
    }
  }

  void _addExplosion(Offset position, int color) {
    explosions.add(AstroExplosion(position: position, color: color));
    if (explosions.length > 18) explosions.removeAt(0);
  }

  void _awardPoints(int points) {
    _bonusPoints += points;
    _score = _survivalPoints.floor() + _bonusPoints;
  }

  double _enemyRadius(AstroEnemyKind kind) {
    final factor = switch (kind) {
      AstroEnemyKind.basic => 0.027,
      AstroEnemyKind.zigzag => 0.03,
      AstroEnemyKind.fast => 0.021,
    };
    return (_viewport.shortestSide * factor).clamp(9.0, 17.0);
  }

  double _enemySpeedFactor(AstroEnemyKind kind) => switch (kind) {
    AstroEnemyKind.basic => 1,
    AstroEnemyKind.zigzag => 0.9,
    AstroEnemyKind.fast => 1.42,
  };

  bool _overlaps(Offset a, double radiusA, Offset b, double radiusB) =>
      (a - b).distance <= radiusA + radiusB;

  int _starsForResult() {
    if (_phase != AstroTiltPhase.victory) return 0;
    final scoreThreshold = level.duration * 42;
    final killThreshold = (level.duration / 7).ceil();
    if (health >= level.shipHealth * 0.72 &&
        _enemiesDestroyed >= killThreshold * 2 &&
        _score >= scoreThreshold * 1.65) {
      return 3;
    }
    if (health >= level.shipHealth * 0.35 &&
        _enemiesDestroyed >= killThreshold) {
      return 2;
    }
    return 1;
  }
}
