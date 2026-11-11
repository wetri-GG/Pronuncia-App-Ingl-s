import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/demo_study_controller.dart';
import '../models/tema.dart';
import 'add_word_screen.dart';
import 'flashcards_screen.dart';

class WordListScreen extends StatelessWidget {
  const WordListScreen({super.key, required this.tema});

  final Tema tema;

  @override
  Widget build(BuildContext context) {
    final words = context.watch<DemoStudyController>().palabrasDe(tema);

    return Scaffold(
      appBar: AppBar(title: Text(tema.nombre)),
      body: Column(
        children: [
          Expanded(
            child: words.isEmpty
                ? const Center(
                    child: Text('Este tema todavía no tiene palabras.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: words.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final palabra = words[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            palabra.ingles,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(palabra.espanol),
                          leading: const Icon(Icons.translate_rounded),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _openAddWord(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir palabra'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: words.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => FlashcardsScreen(tema: tema),
                            ),
                          ),
                    icon: const Icon(Icons.style_rounded),
                    label: const Text('Practicar tarjetas'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddWord(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => AddWordScreen(tema: tema)),
    );
  }
}
