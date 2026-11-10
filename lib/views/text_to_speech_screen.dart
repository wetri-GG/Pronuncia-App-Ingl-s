import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechScreen extends StatefulWidget {
  const TextToSpeechScreen({super.key});

  @override
  State<TextToSpeechScreen> createState() => _TextToSpeechScreenState();
}

class _TextToSpeechScreenState extends State<TextToSpeechScreen> {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  bool _isEnglish = true;
  bool _isSpeaking = false;
  String? _error;

  @override
  void dispose() {
    _tts.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Texto a voz')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Escucha cómo suena tu texto',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF214F3C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Escribe una palabra o frase y elige el idioma.'),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Inglés')),
              ButtonSegment(value: false, label: Text('Español')),
            ],
            selected: {_isEnglish},
            onSelectionChanged: (selection) =>
                setState(() => _isEnglish = selection.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Texto que quieres escuchar',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSpeaking ? _stop : _speak,
            icon: Icon(_isSpeaking ? Icons.stop_rounded : Icons.volume_up),
            label: Text(_isSpeaking ? 'Detener audio' : 'Escuchar'),
          ),
        ],
      ),
    );
  }

  Future<void> _speak() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Escribe algo antes de reproducir el audio.');
      return;
    }

    try {
      await _tts.setLanguage(_isEnglish ? 'en-US' : 'es-ES');
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSpeakCompletion(true);
      setState(() {
        _error = null;
        _isSpeaking = true;
      });
      await _tts.speak(text);
      if (mounted) setState(() => _isSpeaking = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _error = 'No se pudo reproducir el texto: $error';
      });
    }
  }

  Future<void> _stop() async {
    try {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo detener el audio: $error');
      }
    }
  }
}
