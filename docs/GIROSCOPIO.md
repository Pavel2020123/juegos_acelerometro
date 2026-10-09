# Giroscopio en AccelLab

## Qué mide

Un giroscopio mide **velocidad angular** alrededor de los ejes X, Y y Z. La unidad que utiliza `sensors_plus` y que muestra el laboratorio es **rad/s**. Una lectura indica qué tan rápido gira el dispositivo en ese instante; no entrega por sí sola un ángulo absoluto.

Para obtener una orientación aproximada a partir de velocidad angular se debe integrar cada lectura con el tiempo. Esa integración acumula error, por lo que un juego necesita calibración, filtros, límites y una forma de recentrar.

## Servicio real

`lib/core/sensors/gyroscope_service.dart` mantiene una suscripción a `gyroscopeEventStream` y la transforma en `GyroscopeReading`:

```dart
class GyroscopeReading {
  const GyroscopeReading({
    required this.x,
    required this.y,
    required this.z,
    this.timestamp,
  });

  final double x;
  final double y;
  final double z;
  final DateTime? timestamp;
}
```

La apertura del stream utiliza el periodo normal de `sensors_plus`:

```dart
_subscription = gyroscopeEventStream(samplingPeriod: _samplingPeriod).listen(
  (event) => _controller.add(
    GyroscopeReading(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: event.timestamp,
    ),
  ),
  onError: _controller.addError,
);
```

El servicio expone `start()`, `stop()` y `dispose()`. `start()` no duplica la suscripción; `dispose()` cancela el stream y cierra el controlador. La pantalla del laboratorio y Gyro Aim son responsables de liberar el servicio que crean.

## Laboratorio

`SensorLabScreen` muestra X, Y y Z en tarjetas separadas del acelerómetro y el giroscopio. Para el giroscopio, una lectura como `y = 0.8 rad/s` significa que el teléfono está girando alrededor del eje Y a esa velocidad angular en ese instante; no significa que el teléfono esté a 0.8 radianes de una orientación fija.

El laboratorio no convierte rad/s a grados ni integra las lecturas. Esa responsabilidad pertenece a Gyro Aim.

## Integración en Gyro Aim

`GyroAimGame` usa un `Stopwatch` monotónico para obtener el intervalo entre muestras. La secuencia de procesamiento es:

```text
GyroscopeReading
  -> restar sesgo calibrado en X/Y/Z
  -> zona muerta de 0.04
  -> suavizado de X e Y
  -> signos de orientación vertical
  -> sensibilidad × 180 × delta
  -> limitar la mira al área de juego
```

En orientación vertical, los ejes se asignan de forma deliberada:

- Y controla el desplazamiento horizontal.
- X controla el desplazamiento vertical.
- Z se calibra y se conserva, pero no mueve la mira.

La integración real mantiene los signos explícitos:

```dart
final horizontal = _applyDeadZone(reading.y - _biasY);
final vertical = _applyDeadZone(reading.x - _biasX);

const horizontalSign = 1.0;
const verticalSign = -1.0;
final movement = Offset(
  _filteredHorizontal * horizontalSign * _sensitivity * 180 * dt,
  _filteredVertical * verticalSign * _sensitivity * 180 * dt,
);
_aimPosition = _clampAim(_aimPosition + movement);
```

El intervalo de una muestra se limita a `maxSampleDelta = 0.12`. El objetivo es que una pausa, una pérdida de foco o una entrega tardía de eventos no convierta una lectura acumulada en un salto grande.

## Calibración

Al pulsar **Iniciar partida**, Gyro Aim entra en `calibrating` durante 0.7 segundos. El teléfono debe permanecer quieto. El juego calcula el promedio de las muestras recibidas:

```dart
_biasX = _calibrationX / _calibrationSamples;
_biasY = _calibrationY / _calibrationSamples;
_biasZ = _calibrationZ / _calibrationSamples;
```

Si no llega ninguna lectura, la fase pasa a `error` y la pantalla informa que el giroscopio no está disponible. Si el juego se pausa, detiene el reloj, limpia filtros y anula el intervalo de la siguiente muestra. Al reanudar, empieza un intervalo nuevo para no integrar lecturas antiguas.

## Sensibilidad y recentrado

La sensibilidad por defecto es 1.0 y la interfaz permite valores entre 0.4 y 2.4. El control solo escala la respuesta del desplazamiento; no cambia el temporizador, la detección de objetivos ni la física de límites.

**Centrar mira** coloca la mira en el centro del área jugable y limpia los filtros. No elimina la deriva física del sensor; solo corrige la posición visible para continuar jugando.

## Juego y estados

Una ronda dura 30 segundos. Hay un objetivo visible, cada acierto suma 10 puntos, cada disparo incrementa el contador y los resultados calculan la precisión como aciertos divididos por disparos. Las fases son:

```text
intro -> calibrating -> playing -> results
                         │   └──> paused -> playing
                         └──────> error
```

El juego escucha el giroscopio durante calibración y juego. Se detiene al llegar a resultados, al detectar un error o al cerrar la pantalla. Los eventos de disparo se traducen al efecto `AppSound.mainShot` desde `GyroAimScreen`.

## Deriva y limitaciones

- La integración de velocidad angular acumula pequeñas desviaciones; el recentrado permite corregirlas durante la ronda.
- El sesgo puede cambiar con la temperatura, la posición o el dispositivo; conviene recalibrar con el teléfono quieto.
- El orden de los ejes y su signo debe comprobarse en el teléfono final. La implementación actual está definida para orientación vertical.
- Un emulador puede ejecutar la interfaz y las pruebas, pero no demuestra una respuesta física representativa.
- Gyro Aim requiere una lectura real para salir de calibración; sin ella pasa a estado de error en lugar de inventar una orientación.

## Archivos relacionados

- `lib/core/sensors/gyroscope_service.dart`
- `lib/games/gyro_aim/gyro_aim_game.dart`
- `lib/games/gyro_aim/gyro_aim_screen.dart`
- `lib/screens/sensor_lab/sensor_lab_screen.dart`
- `test/gyro_aim_test.dart`
