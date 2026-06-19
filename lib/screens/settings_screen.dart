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
  static const double _wideBreakpoint = 880;

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
    final wide = MediaQuery.of(context).size.width >= _wideBreakpoint;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      // Apply the chosen settings font to this whole screen.
      body: Theme(
        data: theme.copyWith(
          textTheme:
              theme.textTheme.apply(fontFamily: settings.settingsFont.family),
        ),
        child: wide
            ? _wide(settings)
            : _stacked(_sections(context, settings)),
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

  /// Wide/desktop: a centred two-column layout. The Setup strip spans the top.
  /// The left column is wider and holds the sections that need room for long
  /// values (API Key, Downloads); the right column holds the compact controls.
  Widget _wide(SettingsProvider settings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _panel('Setup', _SetupProgress(hasApiKey: settings.hasApiKey)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _panel('API Key', _apiKey(settings)),
                        const SizedBox(height: 16),
                        _panel('Downloads', _downloads(settings)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _panel('Default Model', _defaultModel(settings)),
                        const SizedBox(height: 16),
                        _panel('Appearance', _appearance(settings)),
                        const SizedBox(height: 16),
                        _panel('Fonts', _fonts(settings)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(String title, Widget child) =>
      SectionPanel(title: title, child: child);

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
          wrap: true,
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
        // A compact segmented control instead of three full-height radio rows.
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('System'),
              icon: Icon(Icons.brightness_auto),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode_outlined),
            ),
          ],
          selected: {settings.themeMode},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              context.read<SettingsProvider>().setThemeMode(s.first),
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
          wrap: true,
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

  /// Fonts listed alphabetically by display name.
  static final List<AppFont> _sortedFonts = AppFont.values.toList()
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

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
            // Cap the menu so it shows ~5 entries then scrolls, instead of
            // stretching down the whole screen.
            menuMaxHeight: 5 * kMinInteractiveDimension,
            onChanged: (f) {
              if (f != null) onChanged(f);
            },
            items: [
              for (final f in _sortedFonts)
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
