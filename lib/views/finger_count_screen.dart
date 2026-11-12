import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/demo_study_controller.dart';
import '../utils/finger_count_assessment.dart';

class FingerCountScreen extends StatefulWidget {
  const FingerCountScreen({super.key});

  @override
  State<FingerCountScreen> createState() => _FingerCountScreenState();
}

class _FingerCountScreenState extends State<FingerCountScreen> {
  CameraController? _cameraController;
  HandLandmarkerPlugin? _handLandmarker;
  StreamSubscription<List<Hand>>? _landmarkSubscription;
  Timer? _noHandTimer;
  final FlutterTts _tts = FlutterTts();
  List<Hand> _hands = const [];
  final List<int> _recentCounts = [];
  int? _detectedCount;
  int _manualCount = 0;
  String? _error;
  bool _isInitializing = true;
  bool _isSaving = false;
  bool _usingAutoDetection = true;
  DateTime _lastLandmarkUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _hasHandCamera => defaultTargetPlatform == TargetPlatform.android;

  int get _selectedCount =>
      _usingAutoDetection ? (_detectedCount ?? _manualCount) : _manualCount;

  @override
  void initState() {
    super.initState();
    if (_hasHandCamera) {
      unawaited(_initializeCamera());
    } else {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    _noHandTimer?.cancel();
    _landmarkSubscription?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _handLandmarker?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    return Scaffold(
      appBar: AppBar(title: const Text('Contar con los dedos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Muestra un número con la mano',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Cuenta los dedos y practica decir el número en inglés.'),
          if (_hasHandCamera) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _isInitializing
                    ? const Center(child: CircularProgressIndicator())
                    : controller?.value.isInitialized == true
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(controller!),
                          CustomPaint(
                            painter: _LandmarkPainter(
                              hands: _hands,
                              previewSize: controller.value.previewSize!,
                              lensDirection:
                                  controller.description.lensDirection,
                              sensorOrientation:
                                  controller.description.sensorOrientation,
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: _CountBadge(
                              count: _usingAutoDetection
                                  ? _detectedCount
                                  : _manualCount,
                              isDetected:
                                  _usingAutoDetection && _detectedCount != null,
                              isManual: !_usingAutoDetection,
                            ),
                          ),
                        ],
                      )
                    : _CameraUnavailable(error: _error),
              ),
            ),
          ] else
            const _PlatformNotice(
              message:
                  'La detección automática de manos está disponible en Android. '
                  'Puedes elegir el número manualmente en esta plataforma.',
            ),
          if (_error != null && _hasHandCamera) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Alternativa táctil',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              11,
              (number) => ChoiceChip(
                label: Text('$number'),
                selected: !_usingAutoDetection && _manualCount == number,
                onSelected: (_) => setState(() {
                  _usingAutoDetection = false;
                  _manualCount = number;
                }),
              ),
            ),
          ),
          if (_hasHandCamera && !_usingAutoDetection)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _usingAutoDetection = true;
                  _detectedCount = _recentCounts.isEmpty
                      ? null
                      : _mostFrequentCount(_recentCounts);
                }),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Volver a detección automática'),
              ),
            ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _numberInEnglish(_selectedCount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('$_selectedCount · ${_numberInSpanish(_selectedCount)}'),
                  IconButton.filledTonal(
                    tooltip: 'Escuchar en inglés',
                    onPressed: () => _speak(_numberInEnglish(_selectedCount)),
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveAttempt,
            icon: const Icon(Icons.check_rounded),
            label: Text(_isSaving ? 'Guardando…' : 'Guardar intento de número'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeCamera() async {
    CameraController? cameraController;
    HandLandmarkerPlugin? landmarker;
    StreamSubscription<List<Hand>>? subscription;
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw StateError(
          'Se necesita permiso de cámara para detectar la mano.',
        );
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No se encontró ninguna cámara.');
      final camera = cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await cameraController.initialize();

      landmarker = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.55,
        delegate: HandLandmarkerDelegate.cpu,
      );
      subscription = landmarker.landmarkStream.listen(
        _onLandmarks,
        onError: (Object error) {
          if (mounted) {
            setState(() => _error = 'Error detectando la mano: $error');
          }
        },
      );

      await cameraController.startImageStream((image) {
        try {
          landmarker!.processFrame(image, camera.sensorOrientation);
        } catch (error) {
          if (mounted && _error == null) {
            setState(() => _error = 'No se pudo analizar la imagen: $error');
          }
        }
      });
      if (!mounted) {
        await subscription.cancel();
        await cameraController.dispose();
        landmarker.dispose();
        return;
      }
      _cameraController = cameraController;
      _handLandmarker = landmarker;
      _landmarkSubscription = subscription;
      setState(() => _isInitializing = false);
    } catch (error) {
      await subscription?.cancel();
      await cameraController?.dispose();
      landmarker?.dispose();
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isInitializing = false;
      });
    }
  }

  void _onLandmarks(List<Hand> hands) {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.difference(_lastLandmarkUpdate) <
        const Duration(milliseconds: 50)) {
      return;
    }
    _lastLandmarkUpdate = now;

    if (hands.isEmpty) {
      setState(() => _hands = const []);
      _noHandTimer ??= Timer(const Duration(milliseconds: 500), () {
        _noHandTimer = null;
        if (!mounted) return;
        setState(() {
          _detectedCount = null;
          _recentCounts.clear();
        });
      });
      return;
    }

    _noHandTimer?.cancel();
    _noHandTimer = null;
    final frameCount = hands
        .fold<int>(
          0,
          (total, hand) => total + countRaisedFingers(hand.landmarks),
        )
        .clamp(0, 10)
        .toInt();
    _recentCounts.add(frameCount);
    if (_recentCounts.length > 5) _recentCounts.removeAt(0);

    setState(() {
      _hands = hands;
      if (_usingAutoDetection) {
        _detectedCount = _mostFrequentCount(_recentCounts);
      }
    });
  }

  int _mostFrequentCount(List<int> counts) {
    final frequencies = <int, int>{};
    for (final count in counts) {
      frequencies.update(
        count,
        (frequency) => frequency + 1,
        ifAbsent: () => 1,
      );
    }

    var mostFrequent = counts.last;
    for (final count in counts.reversed) {
      if (frequencies[count]! > frequencies[mostFrequent]!) {
        mostFrequent = count;
      }
    }
    return mostFrequent;
  }

  Future<void> _saveAttempt() async {
    final english = _numberInEnglish(_selectedCount);
    setState(() => _isSaving = true);
    try {
      final controller = context.read<DemoStudyController>();
      final word = await controller.obtenerOCrearPalabraActividad(
        temaNombre: 'Números',
        ingles: english,
        espanol: _numberInSpanish(_selectedCount),
      );
      await controller.registrarRespuesta(
        word,
        conocida: true,
        origen: 'dedos',
      );
      if (!mounted) return;
      _showMessage('Intento guardado: $english.');
    } catch (error) {
      if (mounted) _showMessage('No se pudo guardar el intento: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _speak(String text) async {
    final speechRate = context.read<AppSettingsController>().speechRate;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(speechRate);
      await _tts.speak(text);
    } catch (error) {
      if (mounted) _showMessage('No se pudo reproducir el audio: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _numberInEnglish(int number) => const [
    'Zero',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
  ][number];

  String _numberInSpanish(int number) => const [
    'cero',
    'uno',
    'dos',
    'tres',
    'cuatro',
    'cinco',
    'seis',
    'siete',
    'ocho',
    'nueve',
    'diez',
  ][number];
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(error ?? 'No se pudo iniciar la cámara.'),
    ),
  );
}

class _PlatformNotice extends StatelessWidget {
  const _PlatformNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.isDetected,
    required this.isManual,
  });

  final int? count;
  final bool isDetected;
  final bool isManual;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        isManual
            ? 'Selección manual: $count'
            : isDetected
            ? 'Detectados: $count'
            : 'Muestra una mano a la cámara',
      ),
    ),
  );
}

class _LandmarkPainter extends CustomPainter {
  static const _connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [0, 17],
    [17, 18],
    [18, 19],
    [19, 20],
  ];

  const _LandmarkPainter({
    required this.hands,
    required this.previewSize,
    required this.lensDirection,
    required this.sensorOrientation,
  });

  final List<Hand> hands;
  final Size previewSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / previewSize.height;
    final pointPaint = Paint()
      ..color = const Color(0xFF7CFFB2)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = const Color(0xFF56D98A)
      ..strokeWidth = 3 / scale
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(sensorOrientation * math.pi / 180);
    if (lensDirection == CameraLensDirection.front) {
      canvas.scale(-1, 1);
      canvas.rotate(math.pi);
    }
    canvas.scale(scale);

    for (final hand in hands) {
      for (final connection in _connections) {
        final start = hand.landmarks[connection[0]];
        final end = hand.landmarks[connection[1]];
        canvas.drawLine(
          Offset(
            (start.x - 0.5) * previewSize.width,
            (start.y - 0.5) * previewSize.height,
          ),
          Offset(
            (end.x - 0.5) * previewSize.width,
            (end.y - 0.5) * previewSize.height,
          ),
          linePaint,
        );
      }
      for (final landmark in hand.landmarks) {
        canvas.drawCircle(
          Offset(
            (landmark.x - 0.5) * previewSize.width,
            (landmark.y - 0.5) * previewSize.height,
          ),
          4 / scale,
          pointPaint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LandmarkPainter oldDelegate) =>
      oldDelegate.hands != hands;
}
