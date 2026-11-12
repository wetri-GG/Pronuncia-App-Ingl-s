import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart';

import '../controllers/app_settings_controller.dart';

class ObjectCameraScreen extends StatefulWidget {
  const ObjectCameraScreen({super.key});

  @override
  State<ObjectCameraScreen> createState() => _ObjectCameraScreenState();
}

class _ObjectCameraScreenState extends State<ObjectCameraScreen> {
  CameraController? _cameraController;
  ARSessionManager? _arSessionManager;
  ARAnchorManager? _arAnchorManager;
  ARObjectManager? _arObjectManager;
  ARPlaneAnchor? _placedAnchor;
  final FlutterTts _tts = FlutterTts();
  String? _englishLabel;
  String? _spanishLabel;
  double? _confidence;
  List<_RecognizedObjectLabel> _labels = const [];
  String? _error;
  bool _isInitializing = true;
  bool _isScanning = false;
  bool _isPlacing = false;
  bool _showAr = false;
  int _detectedPlaneCount = 0;
  String _arStatus = 'Mueve el móvil despacio para buscar una superficie.';

  bool get _supportsMobileVision =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_supportsMobileVision) {
      _initializeCamera();
    } else {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _arSessionManager?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cámara y realidad aumentada')),
      body: !_supportsMobileVision
          ? const _MobileOnlyNotice()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.camera_alt_outlined),
                        label: Text('Identificar'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.view_in_ar_rounded),
                        label: Text('Vista AR'),
                      ),
                    ],
                    selected: {_showAr},
                    onSelectionChanged: (selection) =>
                        _toggleView(selection.first),
                  ),
                ),
                Expanded(child: _showAr ? _buildArView() : _buildCameraView()),
                _buildLabelPanel(),
              ],
            ),
    );
  }

  Widget _buildCameraView() {
    final controller = _cameraController;
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller?.value.isInitialized != true) {
      return _MessagePanel(message: _error ?? 'No se pudo iniciar la cámara.');
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller!),
        if (_isScanning)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(child: CircularProgressIndicator()),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: FilledButton.icon(
              onPressed: _isScanning ? null : _captureAndLabel,
              icon: const Icon(Icons.search_rounded),
              label: Text(
                _isScanning ? 'Identificando…' : 'Identificar objeto',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ARView(
          planeDetectionConfig: PlaneDetectionConfig.horizontal,
          onARViewCreated: _onArViewCreated,
          permissionPromptDescription: 'Pronuncia necesita la cámara para mostrar el modo de realidad aumentada.',
          permissionPromptButtonText: 'Permitir cámara',
        ),
        if (_englishLabel != null)
          Align(
            alignment: const Alignment(0, -0.55),
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface
                      .withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 16,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _englishLabel!,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      _spanishLabel!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MessagePanel(
                message: _englishLabel == null
                    ? 'Identifica primero un objeto en la vista Cámara.'
                    : _arStatus,
              ),
              if (_placedAnchor != null)
                TextButton.icon(
                  onPressed: _isPlacing ? null : _removePlacedObject,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Quitar objeto'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabelPanel() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (_englishLabel == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Text(
          'El reconocimiento funciona en el dispositivo y no envía la imagen a un servidor.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _englishLabel!,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(_spanishLabel!),
                    if (_confidence != null)
                      Text('Confianza: ${(_confidence! * 100).round()}%'),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Pronunciar palabra en inglés',
                onPressed: () => _speak(_englishLabel!, 'en-US'),
                icon: const Icon(Icons.volume_up_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Pronunciar palabra en español',
                onPressed: () => _speak(_spanishLabel!, 'es-ES'),
                icon: const Icon(Icons.translate_rounded),
              ),
            ],
          ),
          if (_labels.length > 1) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '¿No es ese objeto? Elige otra etiqueta:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final label in _labels)
                  ChoiceChip(
                    label: Text(label.english),
                    selected: label.english == _englishLabel,
                    onSelected: (_) => _selectLabel(label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw StateError(
          'Se necesita permiso de cámara para identificar objetos.',
        );
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No se encontró ninguna cámara.');
      final camera = cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _captureAndLabel() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      _isScanning = true;
      _error = null;
    });
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.45),
    );
    try {
      final file = await controller.takePicture();
      final labels = await labeler.processImage(
        InputImage.fromFilePath(file.path),
      );
      if (!mounted) return;
      if (labels.isEmpty) {
        setState(() {
          _labels = const [];
          _englishLabel = null;
          _spanishLabel = null;
          _confidence = null;
          _error = 'No se reconoció un objeto claro. Prueba con otra imagen.';
        });
      } else {
        final candidates =
            labels
                .map(
                  (label) => _RecognizedObjectLabel(
                    english: label.label,
                    confidence: label.confidence,
                  ),
                )
                .toList()
              ..sort(
                (first, second) =>
                    second.confidence.compareTo(first.confidence),
              );
        final distinctCandidates = <String, _RecognizedObjectLabel>{};
        for (final candidate in candidates) {
          distinctCandidates.putIfAbsent(
            candidate.english.toLowerCase(),
            () => candidate,
          );
        }
        final filteredCandidates = distinctCandidates.values.take(5).toList();
        final mostUseful = filteredCandidates.first;
        setState(() {
          _labels = filteredCandidates;
          _setSelectedLabel(mostUseful);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo identificar la imagen: $error');
      }
    } finally {
      await labeler.close();
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _selectLabel(_RecognizedObjectLabel label) {
    setState(() => _setSelectedLabel(label));
  }

  void _setSelectedLabel(_RecognizedObjectLabel label) {
    _englishLabel = label.english;
    _spanishLabel = _translationFor(label.english);
    _confidence = label.confidence;
  }

  void _onArViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    _arSessionManager = sessionManager;
    _arAnchorManager = anchorManager;
    _arObjectManager = objectManager;
    _arStatus = 'Mueve el móvil despacio para buscar una superficie.';
    sessionManager.onError = (error) {
      if (!mounted) return;
      setState(() => _arStatus = 'Error de realidad aumentada: $error');
    };
    sessionManager.onPlaneDetected = (planeCount) {
      if (!mounted) return;
      setState(() {
        _detectedPlaneCount = planeCount;
        _arStatus = planeCount == 0
            ? 'Buscando superficies… mueve el móvil despacio.'
            : 'Superficie detectada. Tócala para colocar el objeto.';
      });
    };
    sessionManager.onPlaneOrPointTap = _placeObjectOnPlane;
    sessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: true,
    );
    objectManager.onInitialize();
  }

  Future<void> _placeObjectOnPlane(List<ARHitTestResult> hitResults) async {
    if (!mounted) return;
    if (_isPlacing || _placedAnchor != null) return;
    final anchorManager = _arAnchorManager;
    final objectManager = _arObjectManager;
    if (_englishLabel == null ||
        anchorManager == null ||
        objectManager == null) {
      if (mounted) {
        setState(() => _arStatus = 'Identifica un objeto antes de colocarlo.');
      }
      return;
    }

    ARHitTestResult? planeHit;
    for (final hit in hitResults) {
      if (hit.type == ARHitTestResultType.plane) {
        planeHit = hit;
        break;
      }
    }
    if (planeHit == null) {
      if (mounted) {
        setState(
          () => _arStatus = 'No se encontró una superficie. Toca otra vez.',
        );
      }
      return;
    }

    setState(() {
      _isPlacing = true;
      _arStatus = 'Colocando $_englishLabel…';
    });

    final anchor = ARPlaneAnchor(transformation: planeHit.worldTransform);
    ARPlaneAnchor? pendingAnchor;
    try {
      final anchorAdded = await anchorManager.addAnchor(anchor);
      if (anchorAdded != true) {
        throw StateError('No se pudo fijar el objeto a la superficie.');
      }
      pendingAnchor = anchor;

      final node = ARNode(
        type: NodeType.localGLTF2,
        uri: 'assets/models/pronuncia_marker.gltf',
        name: 'pronuncia_marker_${DateTime.now().microsecondsSinceEpoch}',
        position: Vector3(0, 0.07, 0),
        scale: Vector3.all(0.12),
      );
      final nodeAdded = await objectManager.addNode(node, planeAnchor: anchor);
      if (nodeAdded != true) {
        throw StateError('No se pudo añadir el marcador 3D.');
      }

      if (!mounted) {
        await anchorManager.removeAnchor(anchor);
        return;
      }
      setState(() {
        _placedAnchor = anchor;
        _arStatus = '$_englishLabel colocado en la superficie.';
      });
      pendingAnchor = null;
    } catch (error) {
      var errorMessage = error.toString();
      if (pendingAnchor != null) {
        try {
          await anchorManager.removeAnchor(pendingAnchor);
        } catch (cleanupError) {
          errorMessage = '$error No se pudo retirar el ancla: $cleanupError';
        }
      }
      if (mounted) {
        setState(
          () => _arStatus = 'No se pudo colocar el objeto: $errorMessage',
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  Future<void> _removePlacedObject() async {
    final anchor = _placedAnchor;
    final anchorManager = _arAnchorManager;
    if (anchor == null || anchorManager == null) return;

    setState(() {
      _isPlacing = true;
      _arStatus = 'Quitando el objeto…';
    });
    try {
      await anchorManager.removeAnchor(anchor);
      if (!mounted) return;
      setState(() {
        _placedAnchor = null;
        _arStatus = _detectedPlaneCount > 0
            ? 'Superficie detectada. Tócala para colocar el objeto.'
            : 'Mueve el móvil despacio para buscar una superficie.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _arStatus = 'No se pudo quitar el objeto: $error');
      }
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  Future<void> _toggleView(bool showAr) async {
    if (showAr &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      setState(() => _error = 'La realidad aumentada requiere Android o iOS.');
      return;
    }
    if (showAr) {
      await _cameraController?.dispose();
      _cameraController = null;
      if (!mounted) return;
      setState(() {
        _error = null;
        _showAr = true;
        _detectedPlaneCount = 0;
        _arStatus = _englishLabel == null
            ? 'Identifica primero un objeto en la vista Cámara.'
            : 'Mueve el móvil despacio para buscar una superficie.';
      });
    } else {
      await _removePlacedObject();
      await _arSessionManager?.dispose();
      _arSessionManager = null;
      _arAnchorManager = null;
      _arObjectManager = null;
      if (!mounted) return;
      setState(() {
        _error = null;
        _showAr = false;
        _isInitializing = true;
      });
      await _initializeCamera();
    }
  }

  String _translationFor(String label) {
    return _translations[label.toLowerCase()] ?? 'Objeto: $label';
  }

  static const _translations = {
    'animal': 'Animal',
    'bird': 'Pájaro',
    'apple': 'Manzana',
    'banana': 'Plátano',
    'backpack': 'Mochila',
    'bicycle': 'Bicicleta',
    'book': 'Libro',
    'cat': 'Gato',
    'chair': 'Silla',
    'couch': 'Sofá',
    'dog': 'Perro',
    'food': 'Comida',
    'fruit': 'Fruta',
    'car': 'Coche',
    'cell phone': 'Teléfono móvil',
    'computer': 'Ordenador',
    'cup': 'Taza',
    'desk': 'Escritorio',
    'flower': 'Flor',
    'laptop': 'Portátil',
    'mobile phone': 'Teléfono móvil',
    'mouse': 'Ratón',
    'orange': 'Naranja',
    'phone': 'Teléfono',
    'remote control': 'Mando a distancia',
    'sofa': 'Sofá',
    'strawberry': 'Fresa',
    'tomato': 'Tomate',
    'water bottle': 'Botella de agua',
    'houseplant': 'Planta',
    'plant': 'Planta',
    'person': 'Persona',
    'water': 'Agua',
    'tree': 'Árbol',
    'television': 'Televisión',
    'tv': 'Televisión',
    'bottle': 'Botella',
    'table': 'Mesa',
  };

  Future<void> _speak(String text, String locale) async {
    final speechRate = context.read<AppSettingsController>().speechRate;
    try {
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(speechRate);
      await _tts.speak(text);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo reproducir el audio: $error');
      }
    }
  }
}

class _MobileOnlyNotice extends StatelessWidget {
  const _MobileOnlyNotice();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Text(
        'La cámara con ML Kit y la realidad aumentada requieren un '
        'dispositivo Android o iOS. En escritorio no se inicia ningún '
        'sensor ni se envían imágenes.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _RecognizedObjectLabel {
  const _RecognizedObjectLabel({
    required this.english,
    required this.confidence,
  });

  final String english;
  final double confidence;
}
