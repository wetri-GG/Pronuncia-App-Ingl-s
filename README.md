# Pronuncia

Aplicacion Flutter para practicar vocabulario y pronunciacion en ingles. El proyecto queda preparado para Dart 3, Material 3 y una estructura MVC con `ChangeNotifier`.

## Entorno

- Flutter estable y Dart 3.
- Plataformas generadas: Android, iOS, Windows y Linux.
- SQLite: `sqflite` en movil y `sqflite_common_ffi` para escritorio.
- La deteccion de manos con MediaPipe se hara con `hand_landmarker`, compatible con Android.
- Para realidad aumentada se usa `ar_flutter_plugin_2`, un fork del plugin original que ya no admite las versiones actuales de Dart. AR se limita a Android/iOS; la alternativa de escritorio se definira como maqueta 2D.

Algunos plugins de voz, camara, manos y realidad aumentada tienen soporte limitado por plataforma. Se habilitaran y probaran en las pantallas donde se necesiten.

## Estructura

```text
lib/
  controllers/  # Estado y logica de presentacion (ChangeNotifier)
  data/         # DatabaseHelper y repositorios SQLite
  models/       # Modelos Tema, Palabra e Intento
  views/        # Pantallas de la aplicacion
  widgets/      # Componentes reutilizables
```

## Dependencias

- Navegacion y estado: `go_router`, `provider`.
- Persistencia: `sqflite`, `sqflite_common_ffi`, `path`, `path_provider`.
- Voz y accesos de dispositivo: `speech_to_text`, `flutter_tts`, `camera`, `permission_handler`.
- Vision: `google_mlkit_pose_detection`, `hand_landmarker`.
- Realidad aumentada: `ar_flutter_plugin_2`.
- Internacionalizacion: `flutter_localizations`, `intl`.
- Catalogo de componentes: `widgetbook` (desarrollo).

## Ejecutar

```powershell
flutter pub get
flutter run -d windows
```

Para compilar aplicaciones Windows, instala Visual Studio con las herramientas de C++ para escritorio y `nuget.exe` en el `PATH` (lo necesita `flutter_tts`). En Windows, Flutter tambien necesita soporte para enlaces simbolicos: habilita el Modo de desarrollador si `flutter pub get` lo solicita. Para compilar Android, instala Android SDK Command-line Tools y acepta sus licencias con `flutter doctor --android-licenses`.
