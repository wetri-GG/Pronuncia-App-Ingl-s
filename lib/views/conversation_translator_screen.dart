import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../controllers/app_settings_controller.dart';

class ConversationTranslatorScreen extends StatefulWidget {
  const ConversationTranslatorScreen({super.key});

  @override
  State<ConversationTranslatorScreen> createState() =>
      _ConversationTranslatorScreenState();
}

class _ConversationTranslatorScreenState
    extends State<ConversationTranslatorScreen> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ConversationTurn> _turns = [];
  bool _englishToSpanish = true;
  bool _isListening = false;
  bool _isTranslating = false;
  String? _error;

  bool get _isSupported => defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversación bilingüe')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'La traducción en el dispositivo está disponible en Android.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final sourceLanguage = _englishToSpanish ? 'Inglés' : 'Español';
    final targetLanguage = _englishToSpanish ? 'Español' : 'Inglés';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversación bilingüe'),
        actions: [
          if (_turns.isNotEmpty)
            IconButton(
              tooltip: 'Borrar conversación',
              onPressed: () => setState(_turns.clear),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Inglés → Español')),
                    ButtonSegment(
                      value: false,
                      label: Text('Español → Inglés'),
                    ),
                  ],
                  selected: {_englishToSpanish},
                  onSelectionChanged: _isTranslating || _isListening
                      ? null
                      : (selection) => setState(() {
                          _englishToSpanish = selection.first;
                          _error = null;
                        }),
                ),
                const SizedBox(height: 8),
                Text(
                  'Habla o escribe en $sourceLanguage; la traducción se leerá en $targetLanguage.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'La primera traducción descarga los modelos de idioma. '
                  'Después funciona sin conexión.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: _turns.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Empieza una conversación con el micrófono o escribiendo una frase.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _turns.length,
                    itemBuilder: (context, index) {
                      final turn = _turns[index];
                      return _TurnCard(
                        turn: turn,
                        targetLocale: _englishToSpanish ? 'es-ES' : 'en-US',
                        onSpeak: () => _speak(turn.translation),
                      );
                    },
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Escribe en $sourceLanguage',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTranslating
                              ? null
                              : _isListening
                              ? _stopListening
                              : _startListening,
                          icon: Icon(
                            _isListening ? Icons.stop_rounded : Icons.mic,
                          ),
                          label: Text(_isListening ? 'Detener' : 'Hablar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isTranslating
                              ? null
                              : () => _translate(_textController.text),
                          icon: _isTranslating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.translate_rounded),
                          label: Text(
                            _isTranslating ? 'Traduciendo…' : 'Traducir',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
            _error = 'No se reconoció la voz: ${error.errorMsg}';
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
            _textController.text = result.recognizedWords;
            _textController.selection = TextSelection.collapsed(
              offset: _textController.text.length,
            );
          });
        },
        listenOptions: SpeechListenOptions(
          localeId: _englishToSpanish ? 'en_US' : 'es_ES',
          listenFor: const Duration(seconds: 30),
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
        _error = 'No se pudo iniciar el micrófono: $error';
      });
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

  Future<void> _translate(String input) async {
    final text = input.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Habla o escribe una frase para traducir.');
      return;
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: _englishToSpanish
          ? TranslateLanguage.english
          : TranslateLanguage.spanish,
      targetLanguage: _englishToSpanish
          ? TranslateLanguage.spanish
          : TranslateLanguage.english,
    );
    setState(() {
      _isTranslating = true;
      _error = null;
    });

    try {
      final translated = await translator.translateText(text);
      if (!mounted) return;
      setState(() {
        _turns.add(_ConversationTurn(text, translated));
        _textController.clear();
      });
      await _speak(translated);
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              'No se pudo traducir. Comprueba la conexión para descargar '
              'los modelos la primera vez. Detalle: $error';
        });
      }
    } finally {
      await translator.close();
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _speak(String text) async {
    final speechRate = context.read<AppSettingsController>().speechRate;
    try {
      await _tts.setLanguage(_englishToSpanish ? 'es-ES' : 'en-US');
      await _tts.setSpeechRate(speechRate);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo reproducir el audio: $error');
      }
    }
  }
}

class _ConversationTurn {
  const _ConversationTurn(this.original, this.translation);

  final String original;
  final String translation;
}

class _TurnCard extends StatelessWidget {
  const _TurnCard({
    required this.turn,
    required this.targetLocale,
    required this.onSpeak,
  });

  final _ConversationTurn turn;
  final String targetLocale;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(turn.original, style: Theme.of(context).textTheme.bodyLarge),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    turn.translation,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Escuchar traducción ($targetLocale)',
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
