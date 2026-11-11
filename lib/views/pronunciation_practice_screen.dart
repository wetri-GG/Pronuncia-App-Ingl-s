import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/demo_study_controller.dart';
import '../models/palabra.dart';
import '../models/tema.dart';
import '../utils/pronunciation_assessment.dart';
import '../widgets/pronunciation_meter.dart';

class PronunciationPracticeScreen extends StatefulWidget {
  const PronunciationPracticeScreen({super.key});

  @override
  State<PronunciationPracticeScreen> createState() =>
      _PronunciationPracticeScreenState();
}

class _PronunciationPracticeScreenState
    extends State<PronunciationPracticeScreen> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _answerController = TextEditingController();
  int? _selectedThemeId;
  int _wordIndex = 0;
  int? _score;
  bool _isListening = false;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final study = context.watch<DemoStudyController>();
    final selectedTheme = _selectedThemeId == null
        ? null
        : study.temaPorId(_selectedThemeId!);
    final words = selectedTheme == null
        ? study.todasLasPalabras
        : study.palabrasDe(selectedTheme);
    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medidor de pronunciación')),
        body: const Center(
          child: Text('Añade palabras al tema para practicar.'),
        ),
      );
    }

    final word = words[_wordIndex % words.length];
    return Scaffold(
      appBar: AppBar(title: const Text('Medidor de pronunciación')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildThemeSelector(study.temas),
          const SizedBox(height: 20),
          _TargetWord(word: word, onSpeak: () => _speak(word.ingles)),
          const SizedBox(height: 20),
          Center(child: PronunciationMeter(score: _score)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSaving
                ? null
                : _isListening
                ? _stopListening
                : _startListening,
            icon: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(_isListening ? 'Detener escucha' : 'Decir la palabra'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _answerController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Texto reconocido (también puedes escribirlo)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {
              _score = null;
              _error = null;
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _assess(word),
            icon: const Icon(Icons.speed_rounded),
            label: const Text('Medir y guardar respuesta'),
          ),
          const SizedBox(height: 8),
          Text(
            'La puntuación compara la palabra esperada con el texto que reconoce el dispositivo; no mide el acento ni la calidad acústica.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_score != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _next(words.length),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Siguiente palabra'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeSelector(List<Tema> topics) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedThemeId,
      decoration: const InputDecoration(
        labelText: 'Tema para practicar',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos los temas'),
        ),
        for (final topic in topics)
          DropdownMenuItem<int?>(value: topic.id, child: Text(topic.nombre)),
      ],
      onChanged: _isSaving || _isListening
          ? null
          : (themeId) => setState(() {
              _selectedThemeId = themeId;
              _wordIndex = 0;
              _score = null;
              _answerController.clear();
              _error = null;
            }),
    );
  }

  Future<void> _startListening() async {
    setState(() => _error = null);
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _error = 'No se pudo reconocer la voz: ${error.errorMsg}';
          });
        },
        onStatus: (status) {
          if (mounted) setState(() => _isListening = status == 'listening');
        },
      );
      if (!available) {
        setState(() => _error = 'El reconocimiento de voz no está disponible.');
        return;
      }
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _answerController.text = result.recognizedWords;
            _answerController.selection = TextSelection.collapsed(
              offset: _answerController.text.length,
            );
            _score = null;
          });
        },
        listenOptions: SpeechListenOptions(
          localeId: 'en_US',
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 4),
          listenMode: ListenMode.dictation,
          partialResults: true,
        ),
      );
      if (mounted) setState(() => _isListening = _speech.isListening);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _error = 'No se pudo iniciar el micrófono: $error';
        });
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo detener el micrófono: $error');
      }
    }
  }

  Future<void> _assess(Palabra word) async {
    final recognized = _answerController.text.trim();
    if (recognized.isEmpty) {
      setState(() => _error = 'Di o escribe la palabra antes de medirla.');
      return;
    }
    final score = pronunciationMatchScore(word.ingles, recognized);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await context.read<DemoStudyController>().registrarRespuesta(
        word,
        conocida: score >= 80,
        origen: 'pronunciacion',
        textoReconocido: recognized,
      );
      if (!mounted) return;
      setState(() => _score = score);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar el intento: $error');
      }
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
      if (mounted) {
        setState(() => _error = 'No se pudo reproducir el audio: $error');
      }
    }
  }

  void _next(int count) {
    setState(() {
      _wordIndex = (_wordIndex + 1) % count;
      _score = null;
      _answerController.clear();
      _error = null;
    });
  }
}

class _TargetWord extends StatelessWidget {
  const _TargetWord({required this.word, required this.onSpeak});

  final Palabra word;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(word.espanol, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              word.ingles,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Escuchar pronunciación de ejemplo',
              onPressed: onSpeak,
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
