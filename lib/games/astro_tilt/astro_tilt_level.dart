class AstroTiltLevel {
  const AstroTiltLevel({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.duration,
    required this.enemySpeed,
    required this.enemySpawnInterval,
    required this.meteorSpawnInterval,
    required this.shipHealth,
    required this.sensitivity,
    required this.maxSpeed,
    required this.powerUpInterval,
    this.hasBoss = false,
    this.bossHealth = 0,
    this.bossWindow = 0,
    this.enemyShotInterval = 1.2,
    this.autoFireInterval = 0.42,
    this.maxDrones = 0,
    this.droneDuration = 10,
    this.tripleShotEnabled = false,
    this.missilesEnabled = false,
    this.specialGain = 0,
  });

  final int id;
  final String name;
  final String description;
  final String difficulty;
  final double duration;
  final double enemySpeed;
  final double enemySpawnInterval;
  final double meteorSpawnInterval;
  final double shipHealth;
  final double sensitivity;
  final double maxSpeed;
  final double powerUpInterval;
  final bool hasBoss;
  final int bossHealth;
  final double bossWindow;
  final double enemyShotInterval;
  final double autoFireInterval;
  final int maxDrones;
  final double droneDuration;
  final bool tripleShotEnabled;
  final bool missilesEnabled;
  final double specialGain;
}

const astroTiltLevel1 = AstroTiltLevel(
  id: 1,
  name: 'Patrulla orbital',
  description: 'Aprende a pilotar mientras despejas una órbita tranquila.',
  difficulty: 'FÁCIL',
  duration: 30,
  enemySpeed: 66,
  enemySpawnInterval: 2.35,
  meteorSpawnInterval: 5.8,
  shipHealth: 100,
  sensitivity: 1050,
  maxSpeed: 300,
  powerUpInterval: 0,
  specialGain: 0,
);

const astroTiltLevel2 = AstroTiltLevel(
  id: 2,
  name: 'Campo de asteroides',
  description: 'Más tráfico, maniobras laterales y suministros orbitales.',
  difficulty: 'MEDIO',
  duration: 40,
  enemySpeed: 88,
  enemySpawnInterval: 1.85,
  meteorSpawnInterval: 3.7,
  shipHealth: 100,
  sensitivity: 1100,
  maxSpeed: 320,
  powerUpInterval: 8.5,
  maxDrones: 1,
  tripleShotEnabled: true,
  missilesEnabled: true,
  specialGain: 11,
);

const astroTiltLevel3 = AstroTiltLevel(
  id: 3,
  name: 'Batalla final',
  description: 'Sobrevive a la flota y derrota al guardián de la órbita.',
  difficulty: 'DIFÍCIL',
  duration: 52,
  enemySpeed: 104,
  enemySpawnInterval: 1.65,
  meteorSpawnInterval: 3.1,
  shipHealth: 120,
  sensitivity: 1150,
  maxSpeed: 340,
  powerUpInterval: 8,
  maxDrones: 2,
  tripleShotEnabled: true,
  missilesEnabled: true,
  specialGain: 13,
  hasBoss: true,
  bossHealth: 18,
  bossWindow: 18,
  enemyShotInterval: 1.25,
);

const astroTiltLevels = [astroTiltLevel1, astroTiltLevel2, astroTiltLevel3];

AstroTiltLevel? nextAstroTiltLevel(AstroTiltLevel current) {
  final nextIndex = current.id;
  if (nextIndex >= astroTiltLevels.length) return null;
  return astroTiltLevels[nextIndex];
}
