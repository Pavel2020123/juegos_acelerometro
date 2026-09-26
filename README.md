# AccelLab

App Flutter con dos minijuegos que muestran distintas formas de usar el acelerómetro.

## Tilt Maze

Laberinto con tres niveles, checkpoints, hielo y láseres. Inclina el teléfono para guiar la esfera hasta el portal. Pasa por los checkpoints en orden; si caes, reapareces en el último.

## Balance Master

Juego de equilibrio con tres niveles de 20, 25 y 30 segundos. Mantén uno, dos o tres objetos sobre una plataforma flotante usando inclinaciones pequeñas. Los niveles avanzados añaden bordes peligrosos e impulsos anunciados con anticipación.

Antes de cada ronda, sostén el teléfono en una posición cómoda y pulsa **Calibrar**. Tras la cuenta regresiva comienza el cronómetro. La barra de estabilidad refleja cambios en la lectura del sensor y se recupera gradualmente al sostener el teléfono estable. Puedes pausar, reintentar o cambiar al control táctil para probarlo en un emulador.

## Controles

Ambos juegos ofrecen un modo táctil alternativo y pausa. Tilt Maze permite recalibrar y ajustar la sensibilidad durante la partida. Balance Master pide calibración al iniciar cada ronda y muestra estabilidad en tiempo real.

## Desarrollo

```sh
flutter pub get
flutter run
flutter test
flutter analyze
```
