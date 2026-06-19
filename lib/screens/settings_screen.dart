import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_font.dart';
import '../models/openrouter_model.dart';
import '../providers/settings_provider.dart';
import '../services/download_service.dart';
import '../widgets/ui_kit.dart';
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
      // Apply the chosen settings font to this whole screen.
      body: Theme(
        data: theme.copyWith(
          textTheme:
              theme.textTheme.apply(fontFamily: settings.settingsFont.family),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SetupProgress(hasApiKey: settings.hasApiKey),
            const SizedBox(height: 16),

            // ── API key ────────────────────────────────────────────────
            SectionPanel(
              title: 'API Key',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabelValueRow(
                    label: 'Status',
                    trailing: StatusChip(
                      settings.hasApiKey ? 'Configured' : 'Missing',
                      color: settings.hasApiKey
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
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

            // ── Default model ──────────────────────────────────────────
            SectionPanel(
              title: 'Default Model',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabelValueRow(
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

            // ── Appearance ─────────────────────────────────────────────
            SectionPanel(
              title: 'Appearance',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RadioGroup<ThemeMode>(
                    groupValue: settings.themeMode,
                    onChanged: (m) {
                      if (m != null) {
                        context.read<SettingsProvider>().setThemeMode(m);
                      }
                    },
                    child: Column(
                      children: [
                        for (final mode in ThemeMode.values)
                          RadioListTile<ThemeMode>(
                            value: mode,
                            title: Text(_themeLabel(mode)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    value: settings.animateModelIndicator,
                    onChanged: (v) => context
                        .read<SettingsProvider>()
                        .setAnimateModelIndicator(v),
                    title: const Text('Show activity indicator while replying'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Downloads ──────────────────────────────────────────────
            SectionPanel(
              title: 'Downloads',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabelValueRow(
                    label: 'Folder',
                    value: settings.downloadDir ?? 'Ask each time (Save as…)',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Desktop: saved files go here (or a Save-As dialog when '
                    'unset). On Android, saving opens the share sheet instead.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final dir =
                              await const DownloadService().chooseDirectory();
                          if (dir != null && context.mounted) {
                            context
                                .read<SettingsProvider>()
                                .setDownloadDir(dir);
                          }
                        },
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Choose folder'),
                      ),
                      const SizedBox(width: 12),
                      if (settings.downloadDir != null)
                        OutlinedButton.icon(
                          onPressed: () => context
                              .read<SettingsProvider>()
                              .setDownloadDir(null),
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Fonts ──────────────────────────────────────────────────
            SectionPanel(
              title: 'Fonts',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FontRow(
                    label: 'Heading',
                    value: settings.headingFont,
                    onChanged: (f) =>
                        context.read<SettingsProvider>().setHeadingFont(f),
                  ),
                  _FontRow(
                    label: 'Your text',
                    value: settings.userFont,
                    onChanged: (f) =>
                        context.read<SettingsProvider>().setUserFont(f),
                  ),
                  _FontRow(
                    label: 'Model output',
                    value: settings.modelFont,
                    onChanged: (f) =>
                        context.read<SettingsProvider>().setModelFont(f),
                  ),
                  _FontRow(
                    label: 'Settings',
                    value: settings.settingsFont,
                    onChanged: (f) =>
                        context.read<SettingsProvider>().setSettingsFont(f),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}

/// A labelled font picker row.
class _FontRow extends StatelessWidget {
  const _FontRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final AppFont value;
  final ValueChanged<AppFont> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label.toUpperCase(), style: theme.textTheme.labelMedium),
          ),
          // A dialog picker (rather than a dropdown overlay) so all options are
          // visible and scrollable regardless of where the row sits on screen.
          OutlinedButton(
            onPressed: () async {
              final picked = await _showFontPicker(context, label, value);
              if (picked != null) onChanged(picked);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value.label, style: TextStyle(fontFamily: value.family)),
                const SizedBox(width: 8),
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a scrollable dialog of all fonts, each previewed in its own family.
Future<AppFont?> _showFontPicker(
  BuildContext context,
  String label,
  AppFont current,
) {
  return showDialog<AppFont>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('$label font'),
      children: [
        SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in AppFont.values)
                ListTile(
                  title: Text(f.label, style: TextStyle(fontFamily: f.family)),
                  trailing:
                      f == current ? const Icon(Icons.check, size: 18) : null,
                  onTap: () => Navigator.of(ctx).pop(f),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A three-step setup progress strip.
class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.hasApiKey});

  final bool hasApiKey;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Setup',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Step(step: 1, label: 'API key', done: hasApiKey, active: !hasApiKey),
          _Step(step: 2, label: 'Model', active: hasApiKey),
          const _Step(step: 3, label: 'Chat'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.step,
    required this.label,
    this.done = false,
    this.active = false,
  });

  final int step;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = done || active ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = done || active ? scheme.onPrimary : scheme.outline;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: done
              ? Icon(Icons.check, size: 16, color: fg)
              : Text('$step', style: TextStyle(color: fg)),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
