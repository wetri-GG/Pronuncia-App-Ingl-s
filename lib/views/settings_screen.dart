import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double? _pendingSpeechRate;
  String? _error;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final speechRate = _pendingSpeechRate ?? settings.speechRate;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_brightness_rounded),
                label: Text('Sistema'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Claro'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Oscuro'),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: _isSaving
                ? null
                : (selection) => _saveThemeMode(selection.first),
          ),
          const SizedBox(height: 28),
          Text('Pronunciación', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Velocidad de voz'),
                  Slider(
                    min: 0.2,
                    max: 0.8,
                    divisions: 12,
                    value: speechRate,
                    label: '${(speechRate * 100).round()}%',
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _pendingSpeechRate = value),
                    onChangeEnd: _saveSpeechRate,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lenta',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Normal',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los ajustes se guardan en este dispositivo y se aplican al audio de las actividades.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_isSaving) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await context.read<AppSettingsController>().setThemeMode(mode);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar el ajuste: $error');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveSpeechRate(double rate) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await context.read<AppSettingsController>().setSpeechRate(rate);
      if (mounted) setState(() => _pendingSpeechRate = null);
    } catch (error) {
      if (mounted) {
        setState(() {
          _pendingSpeechRate = null;
          _error = 'No se pudo guardar la velocidad: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
