# Instalación y ejecución

Estas instrucciones describen el entorno que se pudo comprobar en este checkout de AccelLab. La aplicación no necesita backend, base de datos ni credenciales para ejecutarse.

## Requisitos previos

- Git.
- Flutter 3.47.2 estable.
- Dart 3.13.2, incluido en el SDK de Flutter.
- Android Studio y un Android SDK funcional si se quiere compilar APK.
- Un teléfono Android con acelerómetro y/o giroscopio para una demostración física.
- Cable USB y depuración USB si el teléfono se usa como dispositivo de desarrollo.

El proyecto también contiene carpetas iOS, web y Windows. La compilación iOS requiere macOS y Xcode; no se ejecutó en este entorno Windows. Web y Windows permiten comprobar la interfaz, pero la disponibilidad y el comportamiento de sensores deben verificarse en la plataforma de destino.

## Clonar el repositorio

```powershell
git clone https://github.com/Pavel2020123/juegos_acelerometro.git
cd juegos_acelerometro
```

## Verificar Flutter

```powershell
flutter --version
flutter doctor -v
```

La auditoría local usó:

```text
Flutter 3.47.2 • channel stable
Dart 3.13.2
```

## Instalar dependencias

```powershell
flutter pub get
```

Las versiones directas declaradas en `pubspec.yaml` son `flame: ^1.38.2`, `sensors_plus: ^7.0.0` y `audioplayers: ^6.8.1`. El lockfile actual resuelve Flame 1.38.2, sensors_plus 7.1.0 y audioplayers 6.8.1.

## Problema de rutas con espacios en Windows

En este equipo, Flutter está instalado originalmente bajo:

```text
C:\Users\LENOVO 14ALC6\Documents\flutter
```

La ruta contiene un espacio. El hook de activos nativos del paquete transitorio `objective_c` puede intentar ejecutar el Dart SDK sin comillas y truncar la orden en `C:\Users\LENOVO`. El síntoma es:

```text
"C:\Users\LENOVO" no se reconoce como un comando interno o externo
Building assets for package:objective_c failed
```

En este checkout se comprobó un junction corto:

```text
C:\flutter_sdk
```

La forma segura de trabajar en este entorno es invocar el SDK corto explícitamente:

```powershell
C:\flutter_sdk\bin\flutter.bat pub get
C:\flutter_sdk\bin\flutter.bat analyze
C:\flutter_sdk\bin\flutter.bat test
C:\flutter_sdk\bin\flutter.bat run -d <id-del-dispositivo>
```

También se puede anteponer la ruta corta al `Path` de la sesión actual:

```powershell
$env:Path = "C:\flutter_sdk\bin;$env:Path"
flutter devices
```

Esta solución cambia solamente la resolución de comandos de esa sesión. No es necesario mover el SDK, borrar caches ni editar variables globales. Si se decide modificar un `Path` permanente, primero hay que registrar su valor actual y confirmar que la ruta corta es válida. `android/local.properties` es un archivo local generado por Flutter y puede volver a escribir la ruta larga si se ejecuta el SDK original.

## Ver dispositivos

```powershell
C:\flutter_sdk\bin\flutter.bat devices
```

En la comprobación de este entorno se detectaron Android, Windows y Edge. Para los juegos controlados por sensores se recomienda elegir un teléfono físico Android y no una plataforma de escritorio.

## Depuración USB en Android

1. En el teléfono, abre **Ajustes → Información del teléfono** y pulsa varias veces **Número de compilación** hasta activar las opciones de desarrollador.
2. Activa **Depuración USB**.
3. Conecta el teléfono y acepta la autorización RSA.
4. Comprueba que aparece en `flutter devices`.
5. Ejecuta la app con su identificador:

```powershell
C:\flutter_sdk\bin\flutter.bat run -d <id-del-dispositivo>
```

Durante la exposición conviene mantener el teléfono en orientación vertical para calibrar Tilt Maze, AstroTilt y Gyro Aim según sus controles documentados.

## Ejecutar la aplicación

```powershell
C:\flutter_sdk\bin\flutter.bat run -d <id-del-dispositivo>
```

Desde el catálogo se puede abrir el laboratorio, los selectores de niveles y los tres juegos activos. La primera lectura de cada sensor puede tardar unos instantes; las pantallas muestran un estado de espera o un error si la plataforma no entrega eventos.

## Generar un APK

```powershell
C:\flutter_sdk\bin\flutter.bat build apk --debug
```

El resultado de depuración se escribe normalmente en:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

La configuración `release` del proyecto usa la firma de depuración para pruebas locales. Antes de distribuir un APK es necesario configurar una firma de release real y publicarlo mediante un canal controlado; todavía no existe un GitHub Release oficial.

## Comprobaciones antes de una exposición

```powershell
C:\flutter_sdk\bin\dart.bat format lib test
C:\flutter_sdk\bin\flutter.bat analyze
C:\flutter_sdk\bin\flutter.bat test
C:\flutter_sdk\bin\flutter.bat build apk --debug
```

Después de instalar en el teléfono:

- Mueve el dispositivo en el laboratorio y confirma X, Y, Z y las unidades.
- Calibra cada juego sin mover el teléfono durante la indicación.
- Comprueba el sentido horizontal y vertical antes de mostrar la partida.
- Pausa y vuelve desde segundo plano para confirmar que el tiempo no avanza.
- Verifica música y efectos con el volumen del dispositivo.

## Solución de problemas

### No aparece el teléfono

Comprueba el cable, la autorización USB, la depuración USB y `flutter doctor -v`. En Android, revisa que el dispositivo no esté en modo solo carga.

### El juego informa que el sensor no está disponible

Confirma que el teléfono tiene el sensor, que otra aplicación no lo ha bloqueado y que la lectura aparece en **Laboratorio de sensores**. Gyro Aim necesita una lectura real durante la calibración; AstroTilt ofrece control táctil como alternativa.

### La orientación parece invertida

Mantén el teléfono vertical y repite la calibración. Los signos están definidos en la lógica de cada juego y pueden variar según el modelo. No conviene cambiar el código durante la exposición sin verificar primero el dispositivo.

### El APK falla antes de compilar `objective_c`

Confirma `Get-Command flutter` y usa `C:\flutter_sdk\bin\flutter.bat`. El problema conocido está en la ruta de Windows con espacios, no en la lógica de los juegos.

### No se oye música o disparos

Comprueba el volumen multimedia y que la pantalla esté en una fase activa. `AppAudio` pausa audio al pausar, al enviar la app a segundo plano y al terminar la ronda. Los assets se cargan desde `assets/audio/`, declarado en `pubspec.yaml`.

### iOS

`ios/Runner/Info.plist` incluye `NSMotionUsageDescription`. La compilación y la prueba física de iOS requieren macOS/Xcode y todavía están pendientes en este entorno.
