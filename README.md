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
  data/         # DatabaseHelper y repositorios CRUD SQLite
  models/       # Modelos Tema, Palabra e Intento
  views/        # Pantallas de la aplicacion
  widgets/      # Componentes reutilizables
```

## Pantallas

1. Menu inicial de actividades.
2. Temas y porcentajes de acierto.
3. Lista de palabras de cada tema.
4. Alta de palabras en ingles y espanol.
5. Tarjetas giratorias con pronunciacion TTS.
6. Practica oral por tema, con reconocimiento `en_US` y guardado de intentos.
7. Texto a voz en ingles y espanol.
8. Conversacion y traduccion por voz o texto entre ingles y espanol, con
   traduccion en el dispositivo y modelos descargados en el primer uso.
9. Conteo de hasta diez dedos con dos manos en Android y alternativa tactil.
10. Simon Says con deteccion de poses ML Kit y alternativa de prueba en escritorio.
11. Estadisticas globales, por tema y palabras mas falladas.
12. Camara con reconocimiento de imagen, etiquetas alternativas y modo de
    realidad aumentada.

Los temas, palabras e intentos se guardan en SQLite. El esquema version 2
incluye el origen del intento (`tarjetas`, `voz`, `dedos` o `pose`) y migra las
bases existentes sin perder sus intentos.

## Compatibilidad de vision

- ML Kit para etiquetas de imagen y poses funciona en Android/iOS.
- MediaPipe `hand_landmarker` funciona en Android; otras plataformas muestran
  una alternativa tactil.
- La vista de RA usa ARCore/ARKit en Android/iOS. El nombre detectado se
  presenta como una etiqueta superpuesta a la vista de camara.
- Android requiere API 28 (Android 9) por el plugin de realidad aumentada.
- El reconocimiento de objetos se ejecuta en el dispositivo. Las traducciones
  se resuelven con un diccionario local para las etiquetas conocidas.
- El traductor de conversacion usa ML Kit en Android; los modelos de ingles y
  espanol se descargan la primera vez que se traduce, para no incluirlos dentro
  del APK.
- Para reducir el tamano de las descargas Android sin quitar funciones, compila
  APKs separados por arquitectura con `flutter build apk --release --split-per-abi`.

## Dependencias

- Navegacion y estado: `go_router`, `provider`.
- Persistencia: `sqflite`, `sqflite_common_ffi`, `path`, `path_provider`.
- Voz y accesos de dispositivo: `speech_to_text`, `flutter_tts`, `camera`, `permission_handler`.
- Vision y traduccion: `google_mlkit_image_labeling`, `google_mlkit_pose_detection`,
  `google_mlkit_translation`, `hand_landmarker`.
- Realidad aumentada: `ar_flutter_plugin_2`.
- Internacionalizacion: `flutter_localizations`, `intl`.
- Catalogo de componentes: `widgetbook` (desarrollo).

## Ejecutar

```powershell
flutter pub get
flutter run -d windows
```

Para compilar aplicaciones Windows, instala Visual Studio con las herramientas de C++ para escritorio y `nuget.exe` en el `PATH` (lo necesita `flutter_tts`). En Windows, Flutter tambien necesita soporte para enlaces simbolicos: habilita el Modo de desarrollador si `flutter pub get` lo solicita. Para compilar Android, instala Android SDK Command-line Tools y acepta sus licencias con `flutter doctor --android-licenses`. La deteccion ML Kit en iOS requiere iOS 15.5 o superior.
