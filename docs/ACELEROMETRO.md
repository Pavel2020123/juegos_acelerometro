# Acelerómetro en AccelLab

## Qué es

Un acelerómetro mide la aceleración que experimenta el dispositivo sobre tres ejes. En la práctica, la lectura habitual del sensor puede incluir la componente de la gravedad. Por eso un teléfono quieto puede mostrar un valor grande en el eje que apunta hacia arriba o hacia abajo.

La aplicación representa los ejes como:

- **X:** movimiento lateral según el sistema de coordenadas de la plataforma.
- **Y:** movimiento longitudinal según la orientación de la plataforma.
- **Z:** eje perpendicular al plano principal del dispositivo.

La unidad que se muestra en el laboratorio es **m/s²**. El significado visual de un signo positivo o negativo depende de cómo esté orientado el teléfono y de la convención del sistema operativo.

## Servicio real del proyecto

`lib/core/sensors/accelerometer_service.dart` encapsula `sensors_plus` y publica un modelo propio:

```dart
class AccelerometerReading {
  const AccelerometerReading({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
  });

  final double x;
  final double y;
  final double z;
  final double magnitude;
}
```

La suscripción real calcula la magnitud a partir de los tres ejes:

```dart
_subscription = accelerometerEventStream().listen((event) {
  final magnitude = math.sqrt(
    event.x * event.x + event.y * event.y + event.z * event.z,
  );
  _controller.add(
    AccelerometerReading(
      x: event.x,
      y: event.y,
      z: event.z,
      magnitude: magnitude,
    ),
  );
}, onError: _controller.addError);
```

`start()` evita crear dos listeners y `dispose()` cancela la suscripción y cierra el `StreamController`. Cada pantalla que usa el servicio también libera su propia suscripción.

## Laboratorio

`SensorLabScreen` crea un `AccelerometerService`, escucha sus lecturas y dibuja tres barras para X, Y y Z. Cada valor se muestra con dos decimales y la unidad `m/s²`. Antes de recibir la primera lectura aparece `Esperando lecturas`; si el stream informa un error, la tarjeta pasa a `Error de lectura`.

El laboratorio no filtra ni reorienta las lecturas: su objetivo es mostrar los valores entregados por la plataforma. El procesamiento de cada juego ocurre en su propio modelo.

## Uso en Tilt Maze

`TiltMazeGame` recibe el servicio por inyección para poder probarlo con un stream falso. En `onLoad` se suscribe y guarda la lectura actual. La primera lectura disponible se usa como referencia neutral si todavía no se ha calibrado.

La entrada que llega a la física sigue este recorrido:

```text
lectura X/Y
  -> resta de la postura neutral
  -> signos explícitos: xDirection = -1, yDirection = 1
  -> suavizado por eje
  -> zona muerta de 0.15
  -> aceleración y fricción
  -> velocidad máxima de 500
  -> posición de la esfera
```

La física usa una sensibilidad base de 180, fricción normal de 4.5 y fricción de hielo de 0.65. La pantalla permite modificar el multiplicador de sensibilidad y cambiar al modo táctil. Cuando el juego está pausado, ignora lecturas, pone a cero la velocidad y detiene el motor Flame.

La calibración explícita guarda X e Y de la lectura más reciente:

```dart
bool calibrate() {
  if (!sensorAvailable.value) return false;
  final reading = currentReading.value;
  _neutral = Vector2(reading.x, reading.y);
  _calibrated = true;
  _smoothedAcceleration = Vector2.zero();
  _velocity = Vector2.zero();
  return true;
}
```

El nivel no usa Z para mover la esfera. Z sigue disponible en el laboratorio para explicar la gravedad y la orientación.

## Uso en AstroTilt

`AstroTiltGame` guarda la lectura más reciente y calcula la entrada después de restar la postura neutral:

```dart
final x = -(reading.x - _neutral.dx);
final y = reading.y - _neutral.dy;
```

Después aplica una zona muerta de 0.25, normaliza una inclinación completa alrededor de 2.4 m/s² y suaviza la entrada con un factor de 0.22. La sensibilidad depende del nivel: 1050, 1100 y 1150. La velocidad de la nave queda limitada por el nivel.

El modelo pausa y limpia filtro, entrada táctil y velocidad cuando pasa a `paused`. Si el usuario activa el control táctil, el juego deja de usar la entrada filtrada del sensor hasta que se vuelva a seleccionar el modo sensor.

## Gravedad y orientación

Una lectura cercana a 9.81 m/s² en un solo eje puede corresponder a un teléfono quieto con la gravedad alineada con ese eje. Al inclinarlo, la proyección de la gravedad cambia entre X, Y y Z. Esa señal es útil para controles de inclinación, pero no equivale a un ángulo perfecto y absoluto.

Los signos definidos en los juegos son decisiones de control, no una propiedad universal del acelerómetro. Deben comprobarse en el teléfono de la exposición y ajustarse solo si la experiencia real queda invertida.

## Errores habituales y límites

- **Leer antes de suscribirse:** el laboratorio comienza en estado de espera hasta que llega un evento.
- **Duplicar listeners:** cada servicio evita iniciar una segunda suscripción mientras la primera existe.
- **No cancelar al salir:** puede dejar lecturas y actualizaciones contra una pantalla destruida; las pantallas actuales cancelan y disponen sus servicios.
- **Confundir gravedad con movimiento lineal:** `accelerometerEventStream()` puede incluir gravedad; el proyecto no pretende separar ambos componentes.
- **Usar lecturas acumuladas después de una pausa:** Tilt Maze limpia la entrada y AstroTilt ignora el sensor durante pausa; la validación física debe confirmar el comportamiento del dispositivo elegido.
- **Probar solo con emulador:** los tests simulan eventos, pero un emulador no demuestra la respuesta de un sensor físico.

## Archivos relacionados

- `lib/core/sensors/accelerometer_service.dart`
- `lib/games/tilt_maze/tilt_maze_game.dart`
- `lib/games/astro_tilt/astro_tilt_game.dart`
- `lib/screens/sensor_lab/sensor_lab_screen.dart`
- `test/tilt_maze_game_test.dart`
- `test/astro_tilt_test.dart`
