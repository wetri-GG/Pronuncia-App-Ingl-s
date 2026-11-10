import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/demo_study_controller.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DemoStudyController>();
    final failedWords = controller.palabrasMasFalladas;

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.error != null
          ? Center(
              child: Text(
                'No se pudieron cargar las estadísticas:\n${controller.error}',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aciertos totales',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${controller.porcentajeGlobal}%',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${controller.totalAciertos} aciertos de '
                          '${controller.totalIntentos} intentos',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Aciertos por tema',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                for (final tema in controller.temas)
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(tema.nombre)),
                              Text('${controller.porcentajeAcierto(tema)}%'),
                            ],
                          ),
                          const SizedBox(height: 9),
                          LinearProgressIndicator(
                            value: controller.porcentajeAcierto(tema) / 100,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  'Palabras más falladas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (failedWords.isEmpty)
                  const Card(
                    color: Colors.white,
                    child: ListTile(
                      title: Text('Todavía no hay errores registrados.'),
                    ),
                  )
                else
                  for (final item in failedWords.take(5))
                    Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: const Icon(Icons.error_outline_rounded),
                        title: Text(item.palabra.ingles),
                        subtitle: Text(item.palabra.espanol),
                        trailing: Text('${item.fallos} fallos'),
                      ),
                    ),
                const SizedBox(height: 18),
                Text(
                  'Intentos por actividad',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final entry in _attemptsByOrigin(controller).entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    trailing: Text('${entry.value}'),
                  ),
              ],
            ),
    );
  }

  Map<String, int> _attemptsByOrigin(DemoStudyController controller) {
    const labels = {
      'tarjetas': 'Tarjetas',
      'voz': 'Práctica oral',
      'dedos': 'Contar dedos',
      'pose': 'Simon says',
    };
    final result = <String, int>{};
    for (final intento in controller.todosLosIntentos) {
      final label = labels[intento.origen] ?? intento.origen;
      result.update(label, (count) => count + 1, ifAbsent: () => 1);
    }
    return result;
  }
}
