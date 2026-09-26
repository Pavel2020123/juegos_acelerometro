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
  ),
];
