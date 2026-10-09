# AccelLab

AccelLab es una app Flutter educativa para experimentar con sensores de movimiento mediante tres minijuegos activos:

- **Tilt Maze** usa el acelerómetro para guiar una bolita por tres laberintos.
- **Gyro Aim** usa el giroscopio para mover una mira y acertar objetivos.
- **AstroTilt** usa el acelerómetro para pilotar una nave espacial.

Balance Master se conserva en el repositorio para no perder su lógica y sus pruebas, pero ya no aparece en el catálogo principal.

## Gyro Aim

Gyro Aim recibe velocidad angular real desde `gyroscopeEventStream()` de `sensors_plus`. En posición vertical, el eje Y del giroscopio controla el desplazamiento horizontal de la mira y el eje X controla el desplazamiento vertical. Las lecturas están en radianes por segundo; no representan un ángulo absoluto.

Al comenzar una partida se toman lecturas con el teléfono quieto para estimar el sesgo. Después se integra la velocidad angular con el tiempo transcurrido de un `Stopwatch` monotónico. El intervalo se limita para impedir saltos cuando la app vuelve del segundo plano, se aplica una zona muerta contra el ruido y se suaviza la entrada. El botón **Centrar mira** permite corregir la deriva acumulada. La sensibilidad se puede ajustar durante la partida.

Cada ronda dura 30 segundos. Hay un objetivo visible a la vez, cada acierto suma 10 puntos y los resultados muestran aciertos, disparos y precisión. El juego pausa al enviar la app a segundo plano, no reanuda por sí solo y libera la suscripción al salir.

## Laboratorio de sensores

Desde el catálogo se puede abrir **Laboratorio de sensores** para observar en tiempo real X, Y y Z del acelerómetro en m/s² y del giroscopio en rad/s. Ambas suscripciones se cancelan al abandonar la pantalla.

## Demostración

1. Abre AccelLab y muestra el catálogo de Tilt Maze, Gyro Aim y AstroTilt.
2. Entra en el laboratorio para explicar la diferencia entre aceleración y velocidad angular.
3. Abre Gyro Aim, mantén el celular vertical y pulsa **Iniciar partida**.
4. Durante la calibración deja el teléfono quieto; después gíralo suavemente para llevar la mira al objetivo.
5. Pulsa **Disparar**, muestra la puntuación y vuelve al catálogo para continuar con AstroTilt.

## Ejecutar y probar

```powershell
flutter pub get
flutter run
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

En este equipo, el SDK de Flutter debe estar configurado en `C:\flutter_sdk` para evitar el problema de hooks nativos causado por espacios en la ruta del usuario. La comprobación de ejes, signo y sensibilidad debe hacerse con un teléfono físico; las pruebas automatizadas usan un stream de giroscopio simulado y no sustituyen esa verificación.

## Estructura relevante

- `lib/core/sensors/gyroscope_service.dart`: suscripción y ciclo de vida del giroscopio.
- `lib/games/gyro_aim/gyro_aim_game.dart`: integración temporal, calibración, objetivos, puntuación y fases.
- `lib/games/gyro_aim/gyro_aim_screen.dart`: interfaz, mira, controles, pausa y resultados.
- `lib/screens/sensor_lab/sensor_lab_screen.dart`: visualización de ambos sensores.
- `test/gyro_aim_test.dart`: pruebas deterministas de la lógica con un servicio simulado.
