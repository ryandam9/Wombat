import 'package:auris/auris_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/openrouter_model.dart';
import '../providers/settings_provider.dart';
import 'model_picker_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _keyController;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(
      text: context.read<SettingsProvider>().apiKey ?? '',
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<SettingsProvider>().setApiKey(_keyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SetupProgress(hasApiKey: settings.hasApiKey),
          const SizedBox(height: 16),

          // ── API key ──────────────────────────────────────────────────
          AurisPanel(
            title: 'API Key',
            code: '01',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AurisDataRow(
                  label: 'Status',
                  trailing: AurisBadge(
                    settings.hasApiKey ? 'CONFIGURED' : 'MISSING',
                    variant: settings.hasApiKey
                        ? AurisBadgeVariant.success
                        : AurisBadgeVariant.danger,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    hintText: 'sk-or-...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get a key at openrouter.ai/keys. Stored securely on this '
                  'device and only sent to OpenRouter.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                    const SizedBox(width: 12),
                    if (settings.hasApiKey)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await context
                              .read<SettingsProvider>()
                              .clearApiKey();
                          _keyController.clear();
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Default model ────────────────────────────────────────────
          AurisPanel(
            title: 'Default Model',
            code: '02',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AurisDataRow(
                  label: 'Model',
                  value: settings.defaultModel,
                  highlight: true,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final selected =
                        await Navigator.of(context).push<OpenRouterModel>(
                      MaterialPageRoute(
                          builder: (_) => const ModelPickerScreen()),
                    );
                    if (selected != null && context.mounted) {
                      context
                          .read<SettingsProvider>()
                          .setDefaultModel(selected.id);
                    }
                  },
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('Change model'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Appearance ───────────────────────────────────────────────
          AurisPanel(
            title: 'Appearance',
            code: '03',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final mode in ThemeMode.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: AurisRadio<ThemeMode>(
                      value: mode,
                      groupValue: settings.themeMode,
                      onChanged: (m) =>
                          context.read<SettingsProvider>().setThemeMode(m),
                      label: _themeLabel(mode),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'SYSTEM',
        ThemeMode.light => 'LIGHT',
        ThemeMode.dark => 'DARK',
      };
}

/// A three-step setup progress strip using [AurisStepIndicator].
class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.hasApiKey});

  final bool hasApiKey;

  @override
  Widget build(BuildContext context) {
    return AurisPanel(
      title: 'Setup',
      code: hasApiKey ? 'OK' : 'TODO',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Step(
            step: 1,
            label: 'API key',
            state: hasApiKey
                ? AurisStepState.complete
                : AurisStepState.active,
          ),
          _Step(
            step: 2,
            label: 'Model',
            state: hasApiKey
                ? AurisStepState.active
                : AurisStepState.inactive,
          ),
          const _Step(step: 3, label: 'Chat', state: AurisStepState.inactive),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.step, required this.label, required this.state});

  final int step;
  final String label;
  final AurisStepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AurisStepIndicator(step: step, state: state),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
