import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../controllers/demo_study_controller.dart';

class FingerCountScreen extends StatefulWidget {
  const FingerCountScreen({super.key});

  @override
  State<FingerCountScreen> createState() => _FingerCountScreenState();
}

class _FingerCountScreenState extends State<FingerCountScreen> {
  CameraController? _cameraController;
  HandLandmarkerPlugin? _handLandmarker;
  StreamSubscription<List<Hand>>? _landmarkSubscription;
  final FlutterTts _tts = FlutterTts();
  List<Hand> _hands = const [];
  int? _detectedCount;
  int _manualCount = 0;
  String? _error;
  bool _isInitializing = true;
  bool _isSaving = false;

  bool get _hasHandCamera => defaultTargetPlatform == TargetPlatform.android;

  int get _selectedCount => _detectedCount ?? _manualCount;

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
              color: const Color(0xFF214F3C),
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
                              count: _detectedCount,
                              isDetected: _detectedCount != null,
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
                selected: _detectedCount == null && _manualCount == number,
                onSelected: (_) => setState(() {
                  _detectedCount = null;
                  _manualCount = number;
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _numberInEnglish(_selectedCount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF184B37),
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
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();

      final landmarker = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.65,
        delegate: HandLandmarkerDelegate.cpu,
      );
      final subscription = landmarker.landmarkStream.listen(
        (hands) {
          if (!mounted) return;
          setState(() {
            _hands = hands;
            _detectedCount = hands.isEmpty
                ? null
                : hands
                      .fold<int>(
                        0,
                        (total, hand) => total + _countRaisedFingers(hand),
                      )
                      .clamp(0, 10)
                      .toInt();
          });
        },
        onError: (Object error) {
          if (mounted) {
            setState(() => _error = 'Error detectando la mano: $error');
          }
        },
      );

      _cameraController = controller;
      _handLandmarker = landmarker;
      _landmarkSubscription = subscription;
      await controller.startImageStream((image) {
        try {
          landmarker.processFrame(image, camera.sensorOrientation);
        } catch (error) {
          if (mounted) {
            setState(() => _error = 'No se pudo analizar la imagen: $error');
          }
        }
      });
      if (mounted) setState(() => _isInitializing = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isInitializing = false;
      });
    }
  }

  int _countRaisedFingers(Hand hand) {
    final landmarks = hand.landmarks;
    if (landmarks.length < 21) return 0;

    var count = 0;
    if (_distance(landmarks[4], landmarks[5]) >
        _distance(landmarks[3], landmarks[5]) * 1.15) {
      count++;
    }
    for (final (tip, joint) in [(8, 6), (12, 10), (16, 14), (20, 18)]) {
      if (landmarks[tip].y < landmarks[joint].y) count++;
    }
    return count.clamp(0, 5);
  }

  double _distance(Landmark first, Landmark second) => math.sqrt(
    math.pow(first.x - second.x, 2) + math.pow(first.y - second.y, 2),
  );

  Future<void> _saveAttempt() async {
    final english = _numberInEnglish(_selectedCount);
    final word = context.read<DemoStudyController>().palabraPorIngles(english);
    if (word == null) {
      _showMessage('No existe una tarjeta de vocabulario para $english.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<DemoStudyController>().registrarRespuesta(
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
    try {
      await _tts.setLanguage('en-US');
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
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFE9F1ED),
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.isDetected});

  final int? count;
  final bool isDetected;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white.withValues(alpha: 0.92),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        isDetected ? 'Detectados: $count' : 'Muestra una mano a la cámara',
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
