import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../controllers/demo_study_controller.dart';

class SimonSaysScreen extends StatefulWidget {
  const SimonSaysScreen({super.key});

  @override
  State<SimonSaysScreen> createState() => _SimonSaysScreenState();
}

class _SimonSaysScreenState extends State<SimonSaysScreen> {
  static const _poses = [
    _PoseTarget(
      instruction: 'Levanta los dos brazos',
      word: 'Arms up',
      translation: 'Brazos arriba',
      icon: Icons.accessibility_new_rounded,
    ),
    _PoseTarget(
      instruction: 'Estira el brazo izquierdo',
      word: 'Left arm',
      translation: 'Brazo izquierdo',
      icon: Icons.arrow_back_rounded,
    ),
    _PoseTarget(
      instruction: 'Estira el brazo derecho',
      word: 'Right arm',
      translation: 'Brazo derecho',
      icon: Icons.arrow_forward_rounded,
    ),
  ];

  final _random = Random();
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  int _targetIndex = 0;
  bool _isInitializing = true;
  bool _isChecking = false;
  String? _error;
  String? _feedback;
  bool? _wasCorrect;

  bool get _hasPoseCamera =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  _PoseTarget get _target => _poses[_targetIndex];

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
    if (_hasPoseCamera) {
      _initializeCamera();
    } else {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    return Scaffold(
      appBar: AppBar(title: const Text('Simon says')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Escucha y haz la pose',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text('La cámara comprobará tu postura cuando pulses el botón.'),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _hasPoseCamera
                  ? _isInitializing
                        ? const Center(child: CircularProgressIndicator())
                        : controller?.value.isInitialized == true
                        ? CameraPreview(controller!)
                        : _CameraMessage(
                            message: _error ?? 'Cámara no disponible.',
                          )
                  : const _PlatformMessage(
                      message:
                          'La detección de poses requiere Android o iOS. '
                          'En esta plataforma puedes probar el flujo de juego.',
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Text(
                    'SIMON SAYS',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(
                    _target.icon,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _target.instruction,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_target.word),
                ],
              ),
            ),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Text(
              _feedback!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _wasCorrect == true
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isChecking
                ? null
                : _hasPoseCamera
                ? _captureAndCheckPose
                : () => _savePoseResult(true),
            icon: _isChecking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_hasPoseCamera ? Icons.camera_alt : Icons.check),
            label: Text(
              _hasPoseCamera ? 'Comprobar pose' : 'Simular pose correcta',
            ),
          ),
          if (_wasCorrect != null)
            TextButton(
              onPressed: _nextPose,
              child: const Text('Siguiente instrucción'),
            ),
        ],
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw StateError('Se necesita permiso de cámara para detectar poses.');
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

  Future<void> _captureAndCheckPose() async {
    final camera = _cameraController;
    if (camera == null || !camera.value.isInitialized) {
      setState(() => _error = 'La cámara todavía no está preparada.');
      return;
    }

    setState(() {
      _isChecking = true;
      _error = null;
      _feedback = null;
    });
    try {
      final image = await camera.takePicture();
      final poses = await _poseDetector!.processImage(
        InputImage.fromFilePath(image.path),
      );
      final pose = poses.isEmpty ? null : poses.first;
      final correct = pose != null && _matchesTarget(pose);
      await _savePoseResult(correct);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo analizar la pose: $error');
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  bool _matchesTarget(Pose pose) {
    PoseLandmark? landmark(PoseLandmarkType type) => pose.landmarks[type];

    final leftShoulder = landmark(PoseLandmarkType.leftShoulder);
    final rightShoulder = landmark(PoseLandmarkType.rightShoulder);
    final leftWrist = landmark(PoseLandmarkType.leftWrist);
    final rightWrist = landmark(PoseLandmarkType.rightWrist);
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftWrist == null ||
        rightWrist == null) {
      return false;
    }

    const minConfidence = 0.35;
    if ([
      leftShoulder,
      rightShoulder,
      leftWrist,
      rightWrist,
    ].any((point) => point.likelihood < minConfidence)) {
      return false;
    }

    return switch (_target.word) {
      'Arms up' =>
        leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y,
      'Left arm' => leftWrist.x > leftShoulder.x,
      'Right arm' => rightWrist.x < rightShoulder.x,
      _ => false,
    };
  }

  Future<void> _savePoseResult(bool correct) async {
    try {
      final controller = context.read<DemoStudyController>();
      final word = await controller.obtenerOCrearPalabraActividad(
        temaNombre: 'Simon Says',
        ingles: _target.word,
        espanol: _target.translation,
      );
      await controller.registrarRespuesta(
        word,
        conocida: correct,
        origen: 'pose',
      );
      if (!mounted) return;
      setState(() {
        _wasCorrect = correct;
        _feedback = correct ? '¡Pose correcta!' : 'No se reconoció la pose. Ajusta tu postura e inténtalo otra vez.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar el intento: $error');
      }
    }
  }

  void _nextPose() {
    setState(() {
      var nextIndex = _random.nextInt(_poses.length);
      if (_poses.length > 1 && nextIndex == _targetIndex) {
        nextIndex = (nextIndex + 1) % _poses.length;
      }
      _targetIndex = nextIndex;
      _wasCorrect = null;
      _feedback = null;
      _error = null;
    });
  }
}

class _PoseTarget {
  const _PoseTarget({
    required this.instruction,
    required this.word,
    required this.translation,
    required this.icon,
  });

  final String instruction;
  final String word;
  final String translation;
  final IconData icon;
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _PlatformMessage extends StatelessWidget {
  const _PlatformMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
