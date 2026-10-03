class BalanceObjective {
  const BalanceObjective({
    required this.appearAt,
    required this.objectIndex,
    required this.centerFactor,
    required this.holdSeconds,
    this.widthFactor = 0.25,
    this.availableSeconds = 7,
  });
//hola // hoy tampoco hice nada 
  final double appearAt;
  final int objectIndex;

  /// Position relative to the complete platform width; 0 is its centre.
  final double centerFactor;
  final double holdSeconds;
  final double widthFactor;
  final double availableSeconds;
}

class BalanceMasterLevel {
  const BalanceMasterLevel({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.duration,
    required this.objectCount,
    required this.platformWidthFactor,
    required this.sensitivity,
    required this.friction,
    required this.maxSpeed,
    this.hazardInset = 0,
    this.perturbationInterval = 0,
    this.gustImpulse = 13,
    this.gustWarningSeconds = 1,
    this.dynamicPlatformInterval = 0,
    this.platformShift = 7,
    this.platformInertia = 0.55,
    this.platformMotionSeconds = 2.4,
    this.platformWarningSeconds = 1,
    this.objectives = const [],
    this.objectiveBonus = 420,
    this.scorePerSecond = 65,
    this.comboThreshold = 85,
    this.comboBreakThreshold = 70,
    this.comboBreakSpike = 1,
    this.comboStepSeconds = 3,
  });

  final int id;
  final String name;
  final String description;
  final String difficulty;
  final double duration;
  final int objectCount;
  final double platformWidthFactor;
  final double sensitivity;
  final double friction;
  final double maxSpeed;
  final double hazardInset;
  final double perturbationInterval;
  final double gustImpulse;
  final double gustWarningSeconds;
  final double dynamicPlatformInterval;
  final double platformShift;
  final double platformInertia;
  final double platformMotionSeconds;
  final double platformWarningSeconds;
  final List<BalanceObjective> objectives;
  final int objectiveBonus;
  final double scorePerSecond;
  final double comboThreshold;
  final double comboBreakThreshold;
  final double comboBreakSpike;
  final double comboStepSeconds;
}

const balanceMasterLevels = [
  BalanceMasterLevel(
    id: 1,
    name: 'Equilibrio básico',
    description: 'Encuentra el punto de equilibrio.',
    difficulty: 'FÁCIL',
    duration: 20,
    objectCount: 1,
    platformWidthFactor: 0.82,
    sensitivity: 82,
    friction: 2.0,
    maxSpeed: 115,
    objectives: [
      BalanceObjective(
        appearAt: 8,
        objectIndex: 0,
        centerFactor: 0,
        holdSeconds: 2,
        widthFactor: 0.30,
        availableSeconds: 8,
      ),
    ],
  ),
  BalanceMasterLevel(
    id: 2,
    name: 'Doble equilibrio',
    description: 'Dos objetos, movimientos más precisos.',
    difficulty: 'MEDIO',
    duration: 25,
    objectCount: 2,
    platformWidthFactor: 0.75,
    sensitivity: 88,
    friction: 1.9,
    maxSpeed: 125,
    hazardInset: 8,
    objectives: [
      BalanceObjective(
        appearAt: 4,
        objectIndex: 0,
        centerFactor: -0.10,
        holdSeconds: 1.6,
      ),
      BalanceObjective(
        appearAt: 12,
        objectIndex: 1,
        centerFactor: 0.07,
        holdSeconds: 1.8,
      ),
      BalanceObjective(
        appearAt: 19,
        objectIndex: 0,
        centerFactor: 0.02,
        holdSeconds: 1.5,
        availableSeconds: 5,
      ),
    ],
  ),
  BalanceMasterLevel(
    id: 3,
    name: 'Caos controlado',
    description: 'Tres objetos e impulsos suaves.',
    difficulty: 'DIFÍCIL',
    duration: 30,
    objectCount: 3,
    platformWidthFactor: 0.72,
    sensitivity: 92,
    friction: 1.85,
    maxSpeed: 135,
    hazardInset: 6,
    perturbationInterval: 9,
    dynamicPlatformInterval: 10,
    objectives: [
      BalanceObjective(
        appearAt: 4,
        objectIndex: 0,
        centerFactor: -0.15,
        holdSeconds: 1.5,
        widthFactor: 0.27,
      ),
      BalanceObjective(
        appearAt: 13,
        objectIndex: 1,
        centerFactor: 0.11,
        holdSeconds: 1.6,
        widthFactor: 0.27,
      ),
      BalanceObjective(
        appearAt: 22,
        objectIndex: 2,
        centerFactor: 0.15,
        holdSeconds: 1.6,
        widthFactor: 0.27,
      ),
    ],
  ),
];
