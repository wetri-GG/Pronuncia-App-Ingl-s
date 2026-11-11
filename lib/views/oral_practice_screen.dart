import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/demo_study_controller.dart';
import '../models/palabra.dart';
import '../models/tema.dart';

class OralPracticeScreen extends StatefulWidget {
  const OralPracticeScreen({super.key});

  @override
  State<OralPracticeScreen> createState() => _OralPracticeScreenState();
}

class _OralPracticeScreenState extends State<OralPracticeScreen> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _answerController = TextEditingController();
  int _wordIndex = 0;
  int? _selectedThemeId;
  String _recognizedWords = '';
  String? _feedback;
  bool? _wasCorrect;
  bool _isListening = false;
  bool _isSaving = false;
  String? _speechError;

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DemoStudyController>();
    final selectedTheme = _selectedThemeId == null
        ? null
        : controller.temaPorId(_selectedThemeId!);
    final words = selectedTheme == null
        ? controller.todasLasPalabras
        : controller.palabrasDe(selectedTheme);
    final topics = controller.temas;
    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Práctica oral')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildTopicSelector(topics),
              const Expanded(
                child: Center(
                  child: Text('Este tema todavía no tiene palabras.'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final word = words[_wordIndex % words.length];
    return Scaffold(
      appBar: AppBar(title: const Text('Práctica oral')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildTopicSelector(topics),
          const SizedBox(height: 18),
          Text(
            'Di esta palabra en inglés',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text('Escucha el ejemplo o intenta pronunciarla sin ayuda.'),
          const SizedBox(height: 24),
          _PracticeCard(word: word, onSpeak: () => _speak(word.ingles)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isListening ? _stopListening : _startListening,
            icon: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(_isListening ? 'Detener escucha' : 'Empezar a hablar'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _answerController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'O escribe lo que has dicho',
              border: OutlineInputBorder(),
            ),
          ),
          if (_recognizedWords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Reconocido: $_recognizedWords'),
          ],
          if (_speechError != null) ...[
            const SizedBox(height: 12),
            Text(
              _speechError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_feedback != null) ...[
            const SizedBox(height: 16),
            Text(
              _feedback!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _wasCorrect == true
                    ? const Color(0xFF2E7055)
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSaving
                  ? null
                  : () => _checkAnswer(word, _answerController.text),
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Comprobar respuesta'),
            ),
          ),
          if (_wasCorrect != null) ...[
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

  Future<void> _startListening() async {
    setState(() {
      _speechError = null;
      _recognizedWords = '';
    });
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _speechError = error.errorMsg;
            _isListening = false;
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _isListening = status == 'listening');
        },
      );
      if (!available) {
        setState(() {
          _speechError = 'El reconocimiento de voz no está disponible.';
        });
        return;
      }

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _recognizedWords = result.recognizedWords;
            _answerController.text = result.recognizedWords;
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
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _speechError = 'No se pudo iniciar el micrófono: $error';
      });
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    } catch (error) {
      if (mounted) setState(() => _speechError = 'No se pudo detener: $error');
    }
  }

  Future<void> _speak(String text) async {
    final speechRate = context.read<AppSettingsController>().speechRate;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(speechRate);
      await _tts.speak(text);
    } catch (error) {
      if (!mounted) return;
      setState(() => _speechError = 'No se pudo reproducir el ejemplo: $error');
    }
  }

  Future<void> _checkAnswer(Palabra word, String spokenText) async {
    final normalizedAnswer = _normalize(spokenText);
    if (normalizedAnswer.isEmpty) {
      setState(() {
        _wasCorrect = false;
        _feedback = 'Habla o escribe la palabra antes de comprobarla.';
      });
      return;
    }

    final correct = _isCloseMatch(normalizedAnswer, _normalize(word.ingles));
    setState(() => _isSaving = true);
    try {
      await context.read<DemoStudyController>().registrarRespuesta(
        word,
        conocida: correct,
        origen: 'voz',
        textoReconocido: spokenText.trim(),
      );
      if (!mounted) return;
      setState(() {
        _wasCorrect = correct;
        _feedback = correct ? '¡Correcto!' : 'La respuesta era ${word.ingles}.';
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _speechError = 'No se pudo guardar el intento: $error';
      });
    }
  }

  String _normalize(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  bool _isCloseMatch(String answer, String expected) {
    if (answer == expected) return true;
    if (expected.length < 5 || answer.isEmpty) return false;

    final allowedEdits = expected.length >= 9 ? 2 : 1;
    if ((answer.length - expected.length).abs() > allowedEdits) return false;

    var previous = List<int>.generate(answer.length + 1, (index) => index);
    for (var row = 1; row <= expected.length; row++) {
      final current = List<int>.filled(answer.length + 1, 0)..[0] = row;
      for (var column = 1; column <= answer.length; column++) {
        final substitutionCost =
            expected.codeUnitAt(row - 1) == answer.codeUnitAt(column - 1)
            ? 0
            : 1;
        current[column] = [
          current[column - 1] + 1,
          previous[column] + 1,
          previous[column - 1] + substitutionCost,
        ].reduce((left, right) => left < right ? left : right);
      }
      previous = current;
    }
    return previous.last <= allowedEdits;
  }

  Widget _buildTopicSelector(List<Tema> topics) {
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
      onChanged: (themeId) {
        setState(() {
          _selectedThemeId = themeId;
          _wordIndex = 0;
          _answerController.clear();
          _feedback = null;
          _wasCorrect = null;
          _recognizedWords = '';
        });
      },
    );
  }

  void _next(int count) {
    setState(() {
      _wordIndex = (_wordIndex + 1) % count;
      _recognizedWords = '';
      _answerController.clear();
      _feedback = null;
      _wasCorrect = null;
      _speechError = null;
    });
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.word, required this.onSpeak});

  final Palabra word;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(word.espanol, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            Icon(
              Icons.record_voice_over_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            const Text('Pronuncia la traducción en inglés'),
            const SizedBox(height: 12),
            IconButton.filledTonal(
              tooltip: 'Escuchar ejemplo',
              onPressed: onSpeak,
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
