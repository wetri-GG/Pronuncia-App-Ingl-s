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
13. Ajustes de apariencia (sistema, claro u oscuro) y velocidad de voz,
    guardados localmente.
14. Medidor de pronunciacion que compara la palabra esperada con la transcripcion
    y registra el resultado en SQLite.

Los temas, palabras e intentos se guardan en SQLite. Una instalación nueva
incluye temas y vocabulario inicial para poder practicar, pero no incluye
intentos: las estadísticas empiezan en cero y se actualizan al realizar
actividades. Los usuarios pueden añadir sus propios temas y palabras. Las
actividades de dedos y Simon Says crean solo la palabra auxiliar correspondiente
cuando se guarda el primer intento, no al abrir la app. El esquema version 5
incluye el origen del intento (`tarjetas`, `voz`, `pronunciacion`, `dedos` o
`pose`) y añade la puntuación numérica del medidor de pronunciación. Migra las
bases existentes sin perder intentos; las puntuaciones antiguas quedan nulas
porque no se pueden reconstruir con exactitud. La migración también restaura el
catálogo inicial en instalaciones que habían recibido una versión sin esos
temas, sin crear intentos ficticios.

### Persistencia de actividades NUI

Cada resultado de una actividad se guarda como una fila de `intentos`, ligada
a la palabra practicada mediante `palabra_id`. `origen` identifica la
actividad: `tarjetas` para autoevaluación, `voz` para práctica oral, `dedos`
para conteo manual o detectado y `pose` para Simon Says. La práctica oral
también guarda el texto reconocido en `texto_reconocido`; el resto de
actividades deja ese campo nulo. El medidor guarda su puntuación de 0 a 100 en
`puntuacion`; los intentos antiguos y el resto de actividades dejan ese campo
nulo. La conversación/traducción no se guarda como intento de vocabulario.

El dominio de un tema se calcula desde los intentos guardados: una palabra
queda dominada al tener al menos un intento acertado (`acierto = 1`), y el tema
se completa cuando todas sus palabras están dominadas. La pantalla de temas
muestra el progreso; al añadir una palabra, el tema vuelve a estar incompleto
hasta que esa palabra también tenga un acierto. No se duplica este agregado en
otra tabla, por lo que permanece consistente con el historial.

`acierto` representa el resultado que comunica cada actividad: autoevaluación
en tarjetas, comparación de la respuesta en voz, coincidencia de pose o
finalización del ejercicio de dedos. En el conteo de dedos el resultado se
registra actualmente como acierto al guardar el número; no mide si el alumno
contestó correctamente a una pregunta independiente.

Se persiste solo el dato necesario para el historial y las estadísticas: no se
guardan grabaciones de voz, imágenes ni fotogramas de cámara. Las consultas de
estadísticas agregan `temas`, `palabras` e `intentos` con `JOIN`: el porcentaje
por tema conserva también los temas sin intentos, y la lista de palabras más
falladas cuenta solo intentos con `acierto = 0`.

## Compatibilidad de vision

- ML Kit para etiquetas de imagen y poses funciona en Android/iOS.
- MediaPipe `hand_landmarker` funciona en Android; otras plataformas muestran
  una alternativa tactil.
- El conteo de dedos compara la extension de cada dedo respecto al eje de la
  mano y suaviza las lecturas recientes; la deteccion depende de la posicion,
  orientacion e iluminacion de la mano.
- La vista de RA usa ARCore/ARKit en Android/iOS. Tras identificar una etiqueta,
  se puede tocar un plano detectado para anclar un marcador 3D local; el nombre
  en ingles y su traduccion se muestran en la vista.
- Android requiere API 28 (Android 9) por el plugin de realidad aumentada.
- El reconocimiento de objetos se ejecuta en el dispositivo. Las traducciones
  se resuelven con un diccionario local para las etiquetas conocidas.
- El traductor de conversacion usa ML Kit en Android; los modelos de ingles y
  espanol se descargan la primera vez que se traduce, para no incluirlos dentro
  del APK.
- El medidor de pronunciacion se basa en la coincidencia del texto reconocido;
  no es una evaluacion acustica del acento ni de fonemas.
- Las preferencias visuales y de velocidad de voz se guardan localmente con
  `shared_preferences`; los intentos del medidor, su puntuación y el texto
  reconocido se guardan en SQLite con origen `pronunciacion`. Al volver a abrir
  el medidor se muestra la última puntuación guardada para la palabra actual.
- Para reducir el tamano de las descargas Android sin quitar funciones, compila
  APKs separados por arquitectura con `flutter build apk --release --split-per-abi`.

## Dependencias

- Navegacion y estado: `go_router`, `provider`.
- Persistencia: `sqflite`, `sqflite_common_ffi`, `path`, `path_provider`.
- Voz y accesos de dispositivo: `speech_to_text`, `flutter_tts`, `camera`,
  `permission_handler`, `shared_preferences`.
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
