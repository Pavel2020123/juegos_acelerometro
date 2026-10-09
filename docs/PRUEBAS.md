# Pruebas y calidad

## Estrategia

AccelLab combina pruebas deterministas de los modelos de juego con pruebas de widgets para las rutas principales. Los sensores se abstraen detrás de servicios pequeños; los tests sustituyen esos servicios por streams controlados para comprobar reglas sin depender del hardware durante cada ejecución.

No existe una carpeta `integration_test/` ni un workflow de GitHub Actions en el repositorio. La validación física de sensores, audio y orientación se mantiene como una etapa manual.

## Pruebas automatizadas por área

### Tilt Maze

`test/tilt_maze_game_test.dart` cubre:

- Tres niveles con rutas y obstáculos diferentes.
- Checkpoints recorridos en orden.
- Respawn exacto en el último checkpoint válido.
- Portal bloqueado hasta completar los checkpoints.
- Calibración, signos de ejes y sensibilidad.
- Pausa, segundo plano y ausencia de saltos al reanudar.
- Reinicio, final del nivel 3 y avance al siguiente nivel.

Los tests montan `TiltMazeGame` en `GameWidget` y usan un servicio de acelerómetro simulado.

### Gyro Aim

`test/gyro_aim_test.dart` usa `_FakeGyroscopeService`, un `StreamController` síncrono que permite emitir lecturas concretas. Comprueba:

- Asignación de ejes en orientación vertical.
- Zona muerta y límite de intervalo de integración.
- Promedio de calibración y eliminación del sesgo.
- Sensibilidad y recentrado.
- Aciertos, fallos, disparos, puntos y precisión.
- Evento de audio de disparo.
- Pausa, reanudación sin lectura acumulada y final de la ronda.
- Reinicio y liberación del servicio.
- Estado de error cuando no hay datos del sensor.

### AstroTilt

`test/astro_tilt_test.dart` cubre niveles, calibración, movimiento, control táctil, límites de velocidad, disparo automático, enemigos, meteoritos, proyectiles especiales, mejoras, drones, misiles, daño, combo, jefe, pausa, ciclo de vida, victoria, derrota y avance de nivel.

### Balance Master legado

`test/balance_master_test.dart` conserva la cobertura del juego que ya no aparece en el catálogo: objetivos, estrellas, calibración, control táctil, pausa, pérdida del sensor, resultados y niveles.

### Widgets y navegación

`test/widget_test.dart` verifica que el catálogo muestra exactamente Tilt Maze, Gyro Aim y AstroTilt, que Balance Master no aparece como tarjeta activa, que Gyro Aim abre y que los selectores existentes y el laboratorio siguen disponibles.

## Validación estática y de formato

Comandos usados en el checkout:

```powershell
dart format lib test
flutter analyze
```

Resultado registrado:

```text
dart format lib test -> correcto, sin archivos pendientes de formato
flutter analyze      -> No issues found!
```

En el entorno Windows con la ruta larga del SDK se debe anteponer `C:\flutter_sdk\bin\` a Flutter y Dart; el motivo está documentado en [INSTALACION.md](INSTALACION.md).

## Ejecución de tests

```powershell
C:\flutter_sdk\bin\flutter.bat test
```

Resultado de la última validación local registrada:

```text
All tests passed! (51 pruebas)
```

Este número corresponde a la suite existente en el checkout y puede cambiar cuando se agreguen pruebas.

## Compilación

```powershell
C:\flutter_sdk\bin\flutter.bat build apk --debug
```

La compilación APK de depuración se ejecutó correctamente en el SDK corto. El artefacto queda bajo `build/app/outputs/flutter-apk/`; `build/` está excluido del control de versiones. La configuración de release usa firma de depuración y no equivale a un APK listo para tienda.

## Pruebas manuales de sensores

Antes de una demostración, ejecutar en un teléfono físico:

1. Abrir **Laboratorio de sensores** y confirmar que llegan X, Y y Z del acelerómetro.
2. Girar el teléfono y confirmar cambios de velocidad angular en el giroscopio.
3. Calibrar Tilt Maze quieto y comprobar el sentido de X/Y.
4. Cambiar la sensibilidad de Tilt Maze y confirmar que solo cambia la respuesta.
5. Activar y desactivar el control táctil de Tilt Maze y AstroTilt.
6. Calibrar Gyro Aim en orientación vertical.
7. Apuntar, disparar y verificar sonido, puntos y precisión.
8. Pausar cada juego, enviarlo a segundo plano y volver a primer plano.
9. Volver al catálogo y confirmar que no quedan lecturas ni audio de la partida anterior.

Estas comprobaciones no se sustituyen por los tests automáticos.

## Limitaciones de emuladores y escritorio

- Los streams falsos de los tests validan reglas, no la calidad del sensor.
- Un emulador puede no proporcionar acelerómetro o giroscopio útiles.
- Windows y Edge sirven para revisar la interfaz y ejecutar pruebas, pero no demuestran el comportamiento físico del teléfono.
- El sentido de los ejes, la deriva del giroscopio y la latencia de audio dependen del dispositivo final.
- iOS tiene la clave `NSMotionUsageDescription`, pero no se compiló ni probó en este entorno Windows.

## Pendientes de calidad

- Tomar y revisar capturas reales de las pantallas para la documentación.
- Repetir la matriz manual en el teléfono exacto de la exposición.
- Verificar iOS y web si se desea declarar esas plataformas como compatibles.
- Crear una firma de release y un GitHub Release antes de ofrecer una descarga pública.
