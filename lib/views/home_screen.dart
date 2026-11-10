import 'package:flutter/material.dart';

import 'conversation_translator_screen.dart';
import 'finger_count_screen.dart';
import 'object_camera_screen.dart';
import 'oral_practice_screen.dart';
import 'simon_says_screen.dart';
import 'statistics_screen.dart';
import 'text_to_speech_screen.dart';
import 'topics_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = [
      _MenuOption(
        title: 'Temas y tarjetas',
        subtitle: 'Organiza y repasa tu vocabulario',
        icon: Icons.style_rounded,
        onTap: () => _open(context, const TopicsScreen()),
      ),
      _MenuOption(
        title: 'Práctica oral',
        subtitle: 'Elige un tema y practica la pronunciación',
        icon: Icons.mic_rounded,
        onTap: () => _open(context, const OralPracticeScreen()),
      ),
      _MenuOption(
        title: 'Texto a voz',
        subtitle: 'Escucha palabras y frases en inglés o español',
        icon: Icons.record_voice_over_rounded,
        onTap: () => _open(context, const TextToSpeechScreen()),
      ),
      _MenuOption(
        title: 'Conversación bilingüe',
        subtitle: 'Traduce y escucha frases entre inglés y español',
        icon: Icons.translate_rounded,
        onTap: () => _open(context, const ConversationTranslatorScreen()),
      ),
      _MenuOption(
        title: 'Contar con los dedos',
        subtitle: 'Practica los números en inglés',
        icon: Icons.back_hand_rounded,
        onTap: () => _open(context, const FingerCountScreen()),
      ),
      _MenuOption(
        title: 'Simon says',
        subtitle: 'Sigue instrucciones con poses',
        icon: Icons.accessibility_new_rounded,
        onTap: () => _open(context, const SimonSaysScreen()),
      ),
      _MenuOption(
        title: 'Estadísticas',
        subtitle: 'Consulta tus aciertos y errores',
        icon: Icons.bar_chart_rounded,
        onTap: () => _open(context, const StatisticsScreen()),
      ),
      _MenuOption(
        title: 'Cámara y realidad aumentada',
        subtitle: 'Identifica objetos y aprende su nombre',
        icon: Icons.view_in_ar_rounded,
        onTap: () => _open(context, const ObjectCameraScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Pronuncia'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              '¿Qué quieres practicar hoy?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF214F3C),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Elige una actividad para mejorar tu inglés.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final option in options) ...[
              _MenuCard(option: option),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _MenuOption {
  const _MenuOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.option});

  final _MenuOption option;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5ECE8)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE9F1ED),
          foregroundColor: colorScheme.primary,
          child: Icon(option.icon),
        ),
        title: Text(
          option.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(option.subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: option.onTap,
      ),
    );
  }
}
