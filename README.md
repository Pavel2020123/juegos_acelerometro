# Tilt Maze

Juego de laberintos para Flutter controlado con el acelerómetro. Incluye tres niveles con checkpoints, hielo y láseres.

## Jugar

1. Elige un nivel y sostén el teléfono en una posición cómoda. Esa posición se calibra al recibir la primera lectura del sensor.
2. Inclina el teléfono para mover la esfera. Usa el botón de calibración si cambias la posición de agarre.
3. Pasa por los checkpoints en orden y llega al portal. Si caes, reapareces en el último checkpoint.

Puedes activar el control táctil con el botón de la mano. En pausa puedes ajustar la sensibilidad o reiniciar el nivel. Si el dispositivo no tiene acelerómetro, aparece un aviso para usar el control táctil.

## Desarrollo

```sh
flutter pub get
flutter run
flutter test
flutter analyze
```
