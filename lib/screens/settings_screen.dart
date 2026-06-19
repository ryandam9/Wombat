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

/// One settings section: a nav entry (icon + title) plus its detail content.
typedef _Section = ({String title, IconData icon, Widget content});

class _SettingsScreenState extends State<SettingsScreen> {
  static const double _wideBreakpoint = 720;

  late final TextEditingController _keyController;
  bool _obscure = true;
  int _selected = 0;

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
    final sections = _sections(context, settings);
    final wide = MediaQuery.of(context).size.width >= _wideBreakpoint;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      // Apply the chosen settings font to this whole screen.
      body: Theme(
        data: theme.copyWith(
          textTheme:
              theme.textTheme.apply(fontFamily: settings.settingsFont.family),
        ),
        child: wide ? _twoPane(sections) : _stacked(sections),
      ),
    );
  }

  // ── Layouts ───────────────────────────────────────────────────────────

  /// Narrow/mobile: every section stacked in a single scrolling column.
  Widget _stacked(List<_Section> sections) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final s in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SectionPanel(title: s.title, child: s.content),
          ),
      ],
    );
  }

  /// Wide/desktop: a section list on the left, the selected detail on the right.
  Widget _twoPane(List<_Section> sections) {
    final theme = Theme.of(context);
    final selected = sections[_selected.clamp(0, sections.length - 1)];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 240,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (var i = 0; i < sections.length; i++)
                ListTile(
                  leading: Icon(sections[i].icon),
                  title: Text(sections[i].title),
                  selected: i == _selected,
                  selectedTileColor:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  onTap: () => setState(() => _selected = i),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(selected.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  selected.content,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────

  List<_Section> _sections(BuildContext context, SettingsProvider settings) => [
        (
          title: 'Setup',
          icon: Icons.checklist_rtl,
          content: _SetupProgress(hasApiKey: settings.hasApiKey),
        ),
        (title: 'API Key', icon: Icons.key, content: _apiKey(settings)),
        (
          title: 'Default Model',
          icon: Icons.smart_toy_outlined,
          content: _defaultModel(settings),
        ),
        (
          title: 'Appearance',
          icon: Icons.palette_outlined,
          content: _appearance(settings),
        ),
        (
          title: 'Downloads',
          icon: Icons.download_outlined,
          content: _downloads(settings),
        ),
        (
          title: 'Fonts',
          icon: Icons.font_download_outlined,
          content: _fonts(settings),
        ),
      ];

  Widget _apiKey(SettingsProvider settings) {
    final theme = Theme.of(context);
    return Column(
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
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Get a key at openrouter.ai/keys. Stored securely on this device and '
          'only sent to OpenRouter.',
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
                  await context.read<SettingsProvider>().clearApiKey();
                  _keyController.clear();
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _defaultModel(SettingsProvider settings) {
    return Column(
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
            final selected = await Navigator.of(context).push<OpenRouterModel>(
              MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
            );
            if (selected != null && mounted) {
              context.read<SettingsProvider>().setDefaultModel(selected.id);
            }
          },
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Change model'),
        ),
      ],
    );
  }

  Widget _appearance(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<ThemeMode>(
          groupValue: settings.themeMode,
          onChanged: (m) {
            if (m != null) context.read<SettingsProvider>().setThemeMode(m);
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
          onChanged: (v) =>
              context.read<SettingsProvider>().setAnimateModelIndicator(v),
          title: const Text('Show activity indicator while replying'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _downloads(SettingsProvider settings) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabelValueRow(
          label: 'Folder',
          value: settings.downloadDir ?? 'Ask each time (Save as…)',
        ),
        const SizedBox(height: 6),
        Text(
          'Desktop: saved files go here (or a Save-As dialog when unset). On '
          'Android, saving opens the share sheet instead.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () async {
                final dir = await const DownloadService().chooseDirectory();
                if (dir != null && mounted) {
                  context.read<SettingsProvider>().setDownloadDir(dir);
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose folder'),
            ),
            const SizedBox(width: 12),
            if (settings.downloadDir != null)
              OutlinedButton.icon(
                onPressed: () =>
                    context.read<SettingsProvider>().setDownloadDir(null),
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _fonts(SettingsProvider settings) {
    final read = context.read<SettingsProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FontRow(
          label: 'Heading',
          value: settings.headingFont,
          onChanged: read.setHeadingFont,
        ),
        _FontRow(
          label: 'Your text',
          value: settings.userFont,
          onChanged: read.setUserFont,
        ),
        _FontRow(
          label: 'Model output',
          value: settings.modelFont,
          onChanged: read.setModelFont,
        ),
        _FontRow(
          label: 'Settings',
          value: settings.settingsFont,
          onChanged: read.setSettingsFont,
        ),
      ],
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}

/// A labelled font picker using a standard, compact dropdown menu.
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
          DropdownButton<AppFont>(
            value: value,
            onChanged: (f) {
              if (f != null) onChanged(f);
            },
            items: [
              for (final f in AppFont.values)
                DropdownMenuItem(
                  value: f,
                  child: Text(f.label, style: TextStyle(fontFamily: f.family)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A three-step setup progress strip.
class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.hasApiKey});

  final bool hasApiKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Step(step: 1, label: 'API key', done: hasApiKey, active: !hasApiKey),
        _Step(step: 2, label: 'Model', active: hasApiKey),
        const _Step(step: 3, label: 'Chat'),
      ],
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
    final color =
        done || active ? scheme.primary : scheme.surfaceContainerHighest;
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
