# AccelLab

App Flutter con minijuegos que muestran distintas formas de usar el acelerómetro.

## AstroTilt

Shooter espacial de tres misiones controlado inclinando el teléfono en ambos
ejes. Calibra una posición cómoda antes de despegar; la nave se mueve con
suavizado e inercia ligera y dispara automáticamente. Esquiva naves y
meteoritos, recoge escudos, disparo doble y reparaciones, y derrota al jefe
final en la tercera misión. El control táctil alternativo permite jugar en un
emulador. La pausa detiene la simulación y se activa automáticamente al salir
de la app.

## Tilt Maze

Laberinto con tres niveles, checkpoints, hielo y láseres. Inclina el teléfono para guiar la esfera hasta el portal. Pasa por los checkpoints en orden; si caes, reapareces en el último.

## Balance Master

Juego de equilibrio con tres niveles de 20, 25 y 30 segundos. Mantén uno, dos o tres objetos sobre una plataforma flotante usando inclinaciones pequeñas. Los niveles avanzados añaden bordes peligrosos e impulsos anunciados con anticipación.

Durante la ronda aparecen zonas luminosas: mantén dentro el objeto indicado para llenar la barra y ganar puntos. La estabilidad alta forma combos; los movimientos bruscos los rompen. El nivel 3 anuncia ráfagas laterales y pequeños desplazamientos de la plataforma. Al ganar recibes de una a tres estrellas según la estabilidad y los objetivos completados.

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
