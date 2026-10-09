# Juegos de AccelLab

El catálogo activo tiene tres juegos. Cada uno recibe el sensor que necesita mediante un servicio y expone una pantalla que gestiona controles, ciclo de vida, HUD y audio.

## Tilt Maze

### Objetivo

Conducir una esfera luminosa por una pista formada por segmentos rectangulares hasta el portal final. La esfera debe atravesar los checkpoints en el orden mostrado.

### Sensor y controles

- **Sensor principal:** acelerómetro, ejes X e Y.
- **Calibración:** guarda la postura neutral de la lectura actual.
- **Respuesta:** resta la neutral, invierte X con `xDirection = -1`, conserva Y con `yDirection = 1`, suaviza, aplica zona muerta y actualiza la velocidad.
- **Control táctil:** se activa desde el HUD y reemplaza la entrada del sensor mientras está habilitado.
- **Pausa:** detiene el motor Flame, limpia la entrada y pausa el audio.
- **Sensibilidad:** el slider de la pantalla escala la aceleración sin cambiar las reglas de colisión.

### Niveles

Los niveles son constantes `TiltMazeLevel` en `lib/games/tilt_maze/tilt_maze_level.dart`. Las coordenadas de la ruta son normalizadas y se escalan al tamaño de la vista.

| Nivel | Nombre | Pista | Checkpoints | Obstáculos |
| --- | --- | ---: | --- | --- |
| 1 | Primer contacto | 0.24 | índices 3 y 5 | Ninguno |
| 2 | Zona congelada | 0.21 | índices 3 y 6 | Una zona de hielo y un láser |
| 3 | Órbita extrema | 0.17 | índices 3 y 7 | Dos zonas de hielo y dos láseres |

### Reglas y estados

`TiltMazeGame` mantiene el tiempo transcurrido, la velocidad, la posición de respawn, el checkpoint actual y el estado del portal.

1. Si la esfera abandona la pista o toca un láser, empieza una animación de caída.
2. Al terminar la caída, reaparece en el último checkpoint válido; si no activó ninguno, vuelve al inicio.
3. Solo se comprueba el siguiente checkpoint esperado. Pasar por encima de uno posterior no adelanta el progreso.
4. El portal se completa únicamente cuando `currentCheckpoint == totalCheckpoints`.
5. Al completar, la velocidad se anula, la esfera y el portal cambian de estado y se emite el evento de victoria.

El HUD se comunica mediante `TiltMazeHudState`. Los componentes Flame principales son `GlowingBallComponent`, `CheckpointComponent`, `GoalPortalComponent`, `IceZoneComponent`, `MovingLaserComponent`, `StartPlatformComponent` y `StarFieldComponent`.

### Archivos y pruebas

- `lib/games/tilt_maze/tilt_maze_level.dart`
- `lib/games/tilt_maze/tilt_maze_game.dart`
- `lib/games/tilt_maze/tilt_maze_screen.dart`
- `lib/games/tilt_maze/tilt_maze_level_select_screen.dart`
- `test/tilt_maze_game_test.dart`

Las pruebas cubren las tres rutas, checkpoints y respawn, calibración, sensibilidad, pausa, portal, final del nivel 3 y avance al siguiente nivel.

## Gyro Aim

### Objetivo

Mover una mira con el giro del teléfono y acertar objetivos durante una ronda de 30 segundos. Hay un objetivo visible a la vez; un acierto suma 10 puntos y genera el siguiente objetivo.

### Sensor y controles

- **Sensor principal:** giroscopio.
- **Orientación documentada:** teléfono vertical; Y mueve horizontalmente y X mueve verticalmente.
- **Calibración:** 0.7 segundos de lecturas quietas para calcular el sesgo X, Y y Z.
- **Sensibilidad:** slider entre 0.4 y 2.4, con valor inicial 1.0.
- **Recentrado:** **Centrar mira** coloca la mira en el centro y limpia los filtros.
- **Disparo:** botón **DISPARAR**; el evento se traduce al efecto `AppSound.mainShot`.
- **Pausa:** detiene el reloj, limpia filtros y espera una nueva muestra al reanudar.

### Integración y reglas

`GyroAimGame` integra la velocidad angular con un `Stopwatch` monotónico. La zona muerta es 0.04, el filtro suaviza X e Y y cada intervalo se limita a 0.12 segundos. La mira siempre se restringe al rectángulo jugable.

Las fases son:

```text
intro -> calibrating -> playing -> results
                         │   └──> paused -> playing
                         └──────> error
```

Si no llega ninguna lectura durante la calibración, se muestra el estado de error. Al finalizar aparecen puntuación, aciertos, disparos y precisión. La pantalla permite volver a jugar o volver al catálogo.

### Audio

Gyro Aim reutiliza `assets/audio/laser shot game sfx.mp3`, registrado como `AppSound.mainShot`, y reclama `Nivel1Avion.mp3` como música de la ronda. `AppAudio` pausa ambos canales cuando la partida se pausa o la aplicación pierde el foco.

### Archivos y pruebas

- `lib/core/sensors/gyroscope_service.dart`
- `lib/games/gyro_aim/gyro_aim_game.dart`
- `lib/games/gyro_aim/gyro_aim_screen.dart`
- `test/gyro_aim_test.dart`

Las pruebas cubren ejes, zona muerta, límite de intervalo, calibración de sesgo, sensibilidad, recentrado, aciertos, fallos, precisión, pausa, resultados, reinicio y ausencia del sensor.

## AstroTilt

### Objetivo

Pilotar una nave espacial en un área vertical, sobrevivir a enemigos y meteoritos, acumular puntos y completar la misión. La nave dispara automáticamente; el jugador se concentra en el movimiento, las colisiones, las mejoras y el pulso especial.

### Sensor y controles

- **Sensor principal:** acelerómetro, con neutral calibrada antes del despegue.
- **Entrada:** X se invierte para el movimiento horizontal; Y controla el eje vertical después de restar la neutral.
- **Procesamiento:** zona muerta 0.25, inclinación completa normalizada alrededor de 2.4, suavizado 0.22, aceleración por nivel y velocidad máxima.
- **Control táctil:** joystick alternativo seleccionable desde el HUD. Si el sensor no está disponible, la pantalla ofrece activarlo.
- **Pausa:** congela simulación, velocidad, timers y audio; el jugador reanuda explícitamente.
- **Especial:** botón **PULSO** cuando la energía llega al 100%; elimina o daña amenazas según la implementación del objeto.

### Misiones

| Nivel | Nombre | Duración | Dificultad | Diferencias |
| --- | --- | ---: | --- | --- |
| 1 | Patrulla orbital | 30 s | Fácil | Enemigos básicos, meteoritos ocasionales y sin mejoras periódicas. |
| 2 | Campo de asteroides | 40 s | Medio | Más tráfico, mejoras, un dron, disparo doble/triple y misiles. |
| 3 | Batalla final | 52 s | Difícil | Nave con más vida, dos drones posibles y jefe con 18 de vida durante la ventana final. |

Los valores completos están en `AstroTiltLevel`: velocidad de enemigos, frecuencia de aparición, vida, sensibilidad, velocidad máxima, intervalo de mejoras, disparo automático y configuración del jefe.

### Entidades y reglas

El modelo mantiene listas de `AstroEnemy`, `AstroProjectile`, `AstroMeteor`, `AstroPowerUp`, `AstroDrone` y `AstroExplosion`, además de un `AstroBoss` opcional. Existen enemigos básicos, zigzag y rápidos; los proyectiles pueden ser normales, de dron o misiles guiados.

Las mejoras implementadas son escudo, reparación, disparo doble, dron, disparo triple, misiles y energía. El combo se reinicia al recibir daño. La victoria normal ocurre cuando termina el tiempo; en el nivel 3 también se exige que el jefe haya sido derrotado. La derrota ocurre cuando la vida llega a cero.

### Fases y audio

```text
calibrating -> countdown -> playing -> victory
                         │       └──> defeated
                         └──────> paused -> estado anterior
```

`AstroTiltScreen` traduce los eventos de disparo principal, disparo de dron, victoria y derrota a `AppAudio`. Cada nivel reclama su pista `Nivel1Avion.mp3`, `Nivel2Avion.mp3` o `Nivel3Avion.mp3` después de calibrar.

### Archivos y pruebas

- `lib/games/astro_tilt/astro_tilt_level.dart`
- `lib/games/astro_tilt/astro_tilt_game.dart`
- `lib/games/astro_tilt/astro_tilt_screen.dart`
- `lib/games/astro_tilt/astro_tilt_level_select_screen.dart`
- `test/astro_tilt_test.dart`

Las pruebas cubren niveles, movimiento, control táctil, disparo automático, drones, triple disparo, misiles, especial, meteoritos, daño, mejoras, jefe, pausa, ciclo de vida, victoria, derrota y avance de nivel.

## Balance Master: código legado

Balance Master conserva archivos y pruebas en el repositorio para no perder su lógica. No está importado por `GameHubScreen` y no debe describirse como uno de los tres juegos principales de AccelLab mientras permanezca fuera del catálogo.

## Capturas pendientes

No existen capturas reales de estos juegos en el repositorio. Para completar una galería documental se necesitan, como mínimo:

1. Catálogo principal.
2. Laboratorio con acelerómetro.
3. Laboratorio con giroscopio.
4. Tilt Maze en partida.
5. Gyro Aim apuntando y en resultados.
6. AstroTilt durante una misión.

Las imágenes deben tomarse en un dispositivo real, comprimirse sin perder legibilidad y guardarse en una carpeta documental con enlaces relativos.
