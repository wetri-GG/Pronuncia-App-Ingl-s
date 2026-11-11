import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/demo_study_controller.dart';
import '../models/palabra.dart';
import '../models/tema.dart';
import '../widgets/flip_card.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key, required this.tema});

  final Tema tema;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  int _currentIndex = 0;
  int _knownInSession = 0;
  bool _isFlipped = false;
  bool _isSavingAnswer = false;
  final FlutterTts _tts = FlutterTts();

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DemoStudyController>();
    final words = controller.palabrasDe(widget.tema);

    return Scaffold(
      appBar: AppBar(title: const Text('Tarjetas')),
      body: words.isEmpty
          ? _buildEmptyState(context)
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _TopicChip(label: widget.tema.nombre),
                        Text(
                          '${_currentIndex + 1} / ${words.length}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: const Color(0xFF659A83)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 8,
                      ),
                      child: FlipCard(
                        palabra: words[_currentIndex],
                        isFlipped: _isFlipped,
                        onSpeak: () => _speak(words[_currentIndex].ingles),
                        onFlip: () => setState(() {
                          _isFlipped = !_isFlipped;
                        }),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      children: [
                        Text(
                          'Toca la tarjeta para girarla',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF659A83)),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSavingAnswer
                                    ? null
                                    : () => _answer(
                                        words[_currentIndex],
                                        known: false,
                                      ),
                                icon: const Icon(Icons.close),
                                label: const Text('No lo sé'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isSavingAnswer
                                    ? null
                                    : () => _answer(
                                        words[_currentIndex],
                                        known: true,
                                      ),
                                icon: const Icon(Icons.check),
                                label: const Text('Lo sé'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _speak(String word) async {
    final speechRate = context.read<AppSettingsController>().speechRate;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(speechRate);
      await _tts.speak(word);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reproducir el audio: $error')),
      );
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'Este tema aun no tiene palabras.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Podras practicarlo cuando agreguemos palabras.'),
          ],
        ),
      ),
    );
  }

  Future<void> _answer(Palabra palabra, {required bool known}) async {
    setState(() => _isSavingAnswer = true);
    final controller = context.read<DemoStudyController>();
    try {
      await controller.registrarRespuesta(palabra, conocida: known);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la respuesta: $error')),
      );
      setState(() => _isSavingAnswer = false);
      return;
    }
    if (!mounted) return;

    if (known) _knownInSession++;

    final words = controller.palabrasDe(widget.tema);
    if (_currentIndex + 1 < words.length) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
        _isSavingAnswer = false;
      });
      return;
    }

    setState(() => _isSavingAnswer = false);
    _showSessionResult(total: words.length);
  }

  void _showSessionResult({required int total}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Practica completada'),
        content: Text('Has acertado $_knownInSession de $total palabras.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Volver a temas'),
          ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0EB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF39775D),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
