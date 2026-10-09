# Guía de exposición de AccelLab

## Objetivo de la demostración

Mostrar que un teléfono no solo tiene sensores: sus lecturas pueden observarse, interpretarse y convertirse en reglas de juego. La presentación debe conectar cada valor X/Y/Z con una acción visible y explicar qué hace la calibración.

La demostración completa puede durar entre cinco y diez minutos:

1. Presentación breve de la app.
2. Laboratorio de sensores.
3. Un recorrido corto por Tilt Maze.
4. Una ronda demostrativa de Gyro Aim.
5. Una misión breve de AstroTilt.

## Preparación antes de recibir al público

- Cargar el teléfono y llevar un cable USB de respaldo.
- Activar la depuración USB y aceptar la autorización del computador.
- Instalar el APK de prueba o preparar `flutter run`.
- Confirmar que el volumen multimedia está activo.
- Cerrar otras aplicaciones que puedan reproducir audio o usar sensores.
- Comprobar `flutter devices` si se ejecutará desde el computador.
- Abrir la app una vez y esperar a que los assets de audio estén listos.
- Mantener el teléfono en orientación vertical para Gyro Aim.
- Tener un segundo dispositivo o un video de respaldo para explicar la idea si el sensor falla.

## Presentación inicial

Explicación sugerida:

> AccelLab es un laboratorio interactivo de Flutter. Primero vemos las lecturas del acelerómetro y del giroscopio; después usamos esos mismos datos para controlar una esfera, una mira y una nave.

Aclara que:

- el acelerómetro informa aceleración y puede incluir gravedad;
- el giroscopio informa velocidad angular en rad/s;
- el giroscopio no entrega directamente un ángulo absoluto;
- la calibración toma una postura de referencia para que el control sea cómodo.

## Laboratorio de sensores

1. Desde el catálogo, pulsa **ABRIR LABORATORIO DE SENSORES**.
2. Muestra la tarjeta **ACELERÓMETRO**.
3. Deja el teléfono quieto y explica que la gravedad puede aparecer principalmente en un eje, con valores cercanos a 9.81 m/s².
4. Inclina suavemente el teléfono y señala cómo cambian X, Y y Z.
5. Muestra la tarjeta **GIROSCOPIO**.
6. Gira el teléfono sobre un eje y explica que los valores representan rapidez de giro en rad/s, no una posición angular acumulada.
7. Si aparece `Esperando lecturas`, espera unos segundos; si aparece `Error de lectura`, continúa con el diagnóstico al final de esta guía.

## Tilt Maze

### Qué explicar

Tilt Maze usa el acelerómetro para mover una esfera por una ruta. La postura actual se calibra como neutral; luego el juego resta esa referencia, suaviza la señal, aplica una zona muerta y convierte la inclinación en aceleración.

### Demostración

1. Regresa al catálogo y abre **TILT MAZE**.
2. Selecciona **Nivel 01 — Primer contacto**.
3. Mantén el teléfono en la postura cómoda que quieres usar y pulsa calibrar.
4. Inclina con movimientos pequeños para seguir la pista.
5. Muestra el contador de checkpoints.
6. Si llegas a una salida de la pista, explica que la esfera cae y regresa al último checkpoint válido.
7. Abre el selector de nuevo y enseña que el nivel 2 añade hielo y láser; el nivel 3 combina más peligros en una pista estrecha.

### Puntos didácticos

- Los checkpoints se recorren en orden.
- El portal no completa el nivel si falta un checkpoint.
- El hielo reduce la fricción y exige anticipar la inclinación.
- La sensibilidad cambia la respuesta, no las reglas de colisión.
- El botón táctil es un modo alternativo, útil si el sensor no responde.

## Gyro Aim

### Qué explicar

Gyro Aim usa el giroscopio en orientación vertical. El eje Y controla el movimiento horizontal de la mira y el eje X el movimiento vertical. La partida calcula un sesgo inicial con el teléfono quieto y después integra la velocidad angular con intervalos pequeños.

### Demostración

1. Regresa al catálogo y abre **GYRO AIM**.
2. Lee la instrucción: mantener el teléfono vertical.
3. Pulsa **INICIAR PARTIDA** y deja el teléfono quieto durante la calibración.
4. Gira suavemente hasta colocar la mira sobre el objetivo.
5. Pulsa **DISPARAR** y muestra el efecto de sonido, el acierto y la puntuación.
6. Mueve la mira fuera del objetivo para demostrar un fallo y cómo cambia la precisión.
7. Ajusta la sensibilidad para mostrar que la mira responde con otra rapidez.
8. Pulsa **Centrar mira** y explica que corrige la posición visible, pero no elimina la deriva física del sensor.
9. Pausa la ronda para mostrar que el tiempo y el audio se detienen.
10. Deja que termine la ronda y muestra resultados, disparos, aciertos y precisión.

### Puntos didácticos

- La ronda dura 30 segundos.
- Cada acierto suma 10 puntos.
- La zona muerta evita que el ruido pequeño mueva la mira.
- El juego limita el intervalo de integración para evitar saltos al volver del segundo plano.
- El sonido de disparo y la música son assets locales gestionados por `AppAudio`.

## AstroTilt

### Qué explicar

AstroTilt usa el acelerómetro para mover una nave en una escena vertical. La nave dispara automáticamente, mientras el jugador esquiva enemigos y meteoritos, recoge mejoras y administra el pulso especial.

### Demostración

1. Regresa al catálogo y abre **ASTROTILT**.
2. Selecciona **Nivel 01 — Patrulla orbital**.
3. Calibra quieto y espera la cuenta regresiva.
4. Inclina el teléfono suavemente para mover la nave.
5. Señala el disparo automático, la vida, la puntuación y el combo.
6. Si quieres evitar usar sensores, activa **CONTROL: TÁCTIL** y mueve el joystick.
7. Para una demostración más completa, explica que el nivel 2 añade mejoras, drones y misiles.
8. Cuenta que el nivel 3 introduce al jefe y exige derrotarlo para completar la misión.

### Puntos didácticos

- La pausa congela la simulación y sus temporizadores.
- El escudo, reparación, disparo múltiple, dron, misiles y energía se modelan como mejoras.
- El audio de disparo, drones, victoria y derrota se emite como eventos de juego y se reproduce desde `AppAudio`.

## Qué hacer si algo falla

### No llegan lecturas

Abre el laboratorio para diferenciar un problema del sensor de un problema del juego. Comprueba permisos, depuración y que el teléfono realmente tenga el sensor.

### El sentido está invertido

Repite la calibración y confirma la orientación vertical. Explica que los signos son una decisión de control definida por el proyecto y que deben ajustarse con una verificación física, no por intuición.

### El giroscopio deriva

Usa **Centrar mira**. Explica que integrar velocidad angular acumula pequeños errores y que recentrar es una corrección práctica, no una medición absoluta.

### No se oye el audio

Revisa el volumen multimedia, que la ronda esté activa y que la aplicación no esté pausada. En el catálogo se reproduce la música de menú; las pantallas de juego reclaman o pausan sus pistas según la fase.

### La compilación Windows falla en `objective_c`

Usa el SDK corto documentado en [INSTALACION.md](INSTALACION.md#problema-de-rutas-con-espacios-en-windows). No cambies código del juego durante la exposición.

## Recomendaciones para grabar la pantalla

- Graba el teléfono en vertical para Gyro Aim y encuadra también las manos para que se entienda la inclinación.
- Activa el volumen antes de grabar, pero evita que la música tape la explicación.
- Captura primero el laboratorio y luego un fragmento corto de cada juego.
- Deja visible el HUD el tiempo suficiente para leer sensor, tiempo, puntos y fase.
- No presentes imágenes de emulador como prueba de sensores físicos.
- Guarda los archivos optimizados en `docs/media/` y enlázalos desde el README cuando estén revisados.

## Lista de comprobación final

- [ ] El teléfono está cargado y tiene volumen.
- [ ] El dispositivo aparece en `flutter devices`.
- [ ] El laboratorio muestra acelerómetro y giroscopio.
- [ ] Tilt Maze calibra, activa checkpoints y permite reiniciar.
- [ ] Gyro Aim calibra, dispara y muestra resultados.
- [ ] AstroTilt calibra, se mueve y cambia a control táctil.
- [ ] La pausa detiene tiempo, movimiento y audio.
- [ ] Al volver del segundo plano no aparece un salto brusco.
- [ ] Las rutas de regreso al catálogo no dejan sensores activos.
- [ ] Hay un plan alternativo si el hardware no entrega lecturas.
