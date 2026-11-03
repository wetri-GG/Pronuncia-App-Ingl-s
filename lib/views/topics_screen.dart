import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/demo_study_controller.dart';
import '../models/tema.dart';
import '../widgets/topic_tile.dart';
import 'flashcards_screen.dart';

class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final temas = context.watch<DemoStudyController>().temas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temas'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: temas.isEmpty
                ? const Center(child: Text('Aun no hay temas.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: temas.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final tema = temas[index];
                      final controller = context.read<DemoStudyController>();
                      return TopicTile(
                        tema: tema,
                        wordCount: controller.palabrasDe(tema).length,
                        accuracy: controller.porcentajeAcierto(tema),
                        onTap: () => _openTopic(context, tema),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => _showAddTopicDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Añadir tema'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openTopic(BuildContext context, Tema tema) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FlashcardsScreen(tema: tema)),
    );
  }

  Future<void> _showAddTopicDialog(BuildContext context) async {
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => const _AddTopicDialog(),
    );
    if (nombre == null || !context.mounted) return;
    context.read<DemoStudyController>().agregarTema(nombre);
  }
}

class _AddTopicDialog extends StatefulWidget {
  const _AddTopicDialog();

  @override
  State<_AddTopicDialog> createState() => _AddTopicDialogState();
}

class _AddTopicDialogState extends State<_AddTopicDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo tema'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre del tema',
            hintText: 'Por ejemplo, Viajes',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Escribe un nombre'
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Añadir')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _nameController.text.trim());
  }
}
