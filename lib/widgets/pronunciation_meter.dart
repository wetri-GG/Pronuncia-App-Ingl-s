import 'package:flutter/material.dart';

class PronunciationMeter extends StatelessWidget {
  const PronunciationMeter({super.key, required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = score;
    final color = value == null
        ? colors.outline
        : value >= 80
        ? colors.primary
        : value >= 50
        ? Colors.orange.shade700
        : colors.error;

    return Semantics(
      label: value == null
          ? 'Medidor de pronunciación, pendiente'
          : 'Medidor de pronunciación, $value por ciento de coincidencia',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 156,
            height: 156,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: value == null ? 0 : value / 100,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    backgroundColor: colors.surfaceContainerHighest,
                    color: color,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value == null ? '--' : '$value%',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: color, fontWeight: FontWeight.w700),
                    ),
                    Text(value == null ? 'Sin medir' : 'Coincidencia'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value == null
                ? 'Di la palabra para ver el resultado.'
                : value >= 80
                ? '¡Muy bien! Se reconoció la palabra.'
                : value >= 50
                ? 'Casi. Inténtalo otra vez.'
                : 'No se reconoció claramente. Prueba de nuevo.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
