class TiltMazePoint {
  const TiltMazePoint(
    this.x,
    this.y,
  );

  /// Coordenadas normalizadas.
  ///
  /// x: 0 = izquierda, 1 = derecha
  /// y: 0 = arriba, 1 = abajo
  final double x;
  final double y;
}

class TiltMazeIceZone {
  const TiltMazeIceZone({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;

  final double width;
  final double height;
}

class TiltMazeLaser {
  const TiltMazeLaser({
    required this.x,
    required this.y,
    required this.speed,
    this.movement = 0.30,
  });

  final double x;
  final double y;

  /// Velocidad de movimiento del láser.
  final double speed;

  /// Cuánto se desplaza de lado a lado.
  final double movement;
}

class TiltMazeLevel {
  const TiltMazeLevel({
    required this.id,
    required this.name,
    required this.description,
    required this.path,
    required this.checkpointIndexes,
    required this.trackWidthFactor,
    this.iceZones = const [],
    this.lasers = const [],
  });

  final int id;

  final String name;

  final String description;

  /// Camino principal del nivel.
  final List<TiltMazePoint> path;

  /// Índices del path donde se colocarán checkpoints.
  final List<int> checkpointIndexes;

  /// Ancho relativo de la pista.
  final double trackWidthFactor;

  final List<TiltMazeIceZone> iceZones;

  final List<TiltMazeLaser> lasers;
}

// ============================================================
// NIVEL 1
// CONTROL BÁSICO
// ============================================================

const tiltMazeLevel1 = TiltMazeLevel(
  id: 1,
  name: 'Primer contacto',
  description: 'Aprende a controlar la esfera.',
  trackWidthFactor: 0.24,
  checkpointIndexes: [
    3,
    5,
  ],
  path: [
    TiltMazePoint(
      0.50,
      1.00,
    ),
    TiltMazePoint(
      0.50,
      0.82,
    ),
    TiltMazePoint(
      0.78,
      0.82,
    ),
    TiltMazePoint(
      0.78,
      0.60,
    ),
    TiltMazePoint(
      0.25,
      0.60,
    ),
    TiltMazePoint(
      0.25,
      0.34,
    ),
    TiltMazePoint(
      0.68,
      0.34,
    ),
    TiltMazePoint(
      0.68,
      0.06,
    ),
  ],
);

// ============================================================
// NIVEL 2
// HIELO + LÁSER
// ============================================================

const tiltMazeLevel2 = TiltMazeLevel(
  id: 2,
  name: 'Zona congelada',
  description: 'Controla la inercia y evita el láser.',
  trackWidthFactor: 0.21,
  checkpointIndexes: [
    3,
    6,
  ],
  path: [
    TiltMazePoint(
      0.50,
      1.00,
    ),
    TiltMazePoint(
      0.50,
      0.86,
    ),
    TiltMazePoint(
      0.20,
      0.86,
    ),
    TiltMazePoint(
      0.20,
      0.68,
    ),
    TiltMazePoint(
      0.76,
      0.68,
    ),
    TiltMazePoint(
      0.76,
      0.48,
    ),
    TiltMazePoint(
      0.32,
      0.48,
    ),
    TiltMazePoint(
      0.32,
      0.27,
    ),
    TiltMazePoint(
      0.72,
      0.27,
    ),
    TiltMazePoint(
      0.72,
      0.05,
    ),
  ],
  iceZones: [
    TiltMazeIceZone(
      x: 0.47,
      y: 0.68,
      width: 0.30,
      height: 0.09,
    ),
  ],
  lasers: [
    TiltMazeLaser(
      x: 0.32,
      y: 0.48,
      speed: 0.9,
      movement: 0.30,
    ),
  ],
);

// ============================================================
// NIVEL 3
// PRECISIÓN
// ============================================================

const tiltMazeLevel3 = TiltMazeLevel(
  id: 3,
  name: 'Órbita extrema',
  description: 'Pista estrecha, hielo y múltiples peligros.',
  trackWidthFactor: 0.17,
  checkpointIndexes: [
    3,
    7,
  ],
  path: [
    TiltMazePoint(
      0.50,
      1.00,
    ),
    TiltMazePoint(
      0.50,
      0.88,
    ),
    TiltMazePoint(
      0.78,
      0.88,
    ),
    TiltMazePoint(
      0.78,
      0.72,
    ),
    TiltMazePoint(
      0.23,
      0.72,
    ),
    TiltMazePoint(
      0.23,
      0.56,
    ),
    TiltMazePoint(
      0.68,
      0.56,
    ),
    TiltMazePoint(
      0.68,
      0.40,
    ),
    TiltMazePoint(
      0.34,
      0.40,
    ),
    TiltMazePoint(
      0.34,
      0.23,
    ),
    TiltMazePoint(
      0.72,
      0.23,
    ),
    TiltMazePoint(
      0.72,
      0.05,
    ),
  ],
  iceZones: [
    TiltMazeIceZone(
      x: 0.48,
      y: 0.72,
      width: 0.34,
      height: 0.08,
    ),
    TiltMazeIceZone(
      x: 0.51,
      y: 0.23,
      width: 0.24,
      height: 0.07,
    ),
  ],
  lasers: [
    TiltMazeLaser(
      x: 0.23,
      y: 0.56,
      speed: 1.0,
      movement: 0.27,
    ),
    TiltMazeLaser(
      x: 0.68,
      y: 0.40,
      speed: 1.15,
      movement: 0.25,
    ),
  ],
);

// ============================================================
// LISTA GENERAL
// ============================================================

const tiltMazeLevels = [
  tiltMazeLevel1,
  tiltMazeLevel2,
  tiltMazeLevel3,
];