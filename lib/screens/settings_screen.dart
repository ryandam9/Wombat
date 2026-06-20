import 'dart:async';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_font.dart';
import '../models/openrouter_model.dart';
import '../providers/settings_provider.dart';
import '../services/download_service.dart';
import '../widgets/ui_kit.dart';
import 'model_picker_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// One settings section: a nav entry (icon + title) plus its detail content.
typedef _Section = ({String title, IconData icon, Widget content});

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const double _wideBreakpoint = 880;

  late final TextEditingController _keyController;
  late final TextEditingController _userNameController;
  late final TextEditingController _aiNameController;
  bool _obscure = true;
  bool _justSaved = false;
  Timer? _savedTimer;

  /// Briefly shows a "Saved" confirmation in the app bar after a setting
  /// changes, so instant-apply controls give a little feedback.
  void _flashSaved() {
    _savedTimer?.cancel();
    setState(() => _justSaved = true);
    _savedTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _keyController = TextEditingController(text: settings.apiKey ?? '');
    _userNameController = TextEditingController(text: settings.userName);
    _aiNameController = TextEditingController(text: settings.aiName);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _userNameController.dispose();
    _aiNameController.dispose();
    _savedTimer?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(settingsProvider.notifier).setApiKey(_keyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final wide = MediaQuery.of(context).size.width >= _wideBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: _justSaved
                ? Padding(
                    key: const ValueKey('saved'),
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('Saved',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
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
  Widget _wide(SettingsState settings) {
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
                        const SizedBox(height: 16),
                        _panel('Default Model', _defaultModel(settings)),
                        const SizedBox(height: 16),
                        _panel('Display names', _names(settings)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _panel('Fonts', _fonts(settings)),
                        const SizedBox(height: 16),
                        _panel('Font size', _fontSize(settings)),
                        const SizedBox(height: 16),
                        _panel('Appearance', _appearance(settings)),
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

  List<_Section> _sections(BuildContext context, SettingsState settings) => [
        (
          title: 'Setup',
          icon: Icons.checklist_rtl,
          content: _SetupProgress(hasApiKey: settings.hasApiKey),
        ),
        (title: 'API Key', icon: Icons.key, content: _apiKey(settings)),
        (
          title: 'Downloads',
          icon: Icons.download_outlined,
          content: _downloads(settings),
        ),
        (
          title: 'Default Model',
          icon: Icons.smart_toy_outlined,
          content: _defaultModel(settings),
        ),
        (
          title: 'Display names',
          icon: Icons.badge_outlined,
          content: _names(settings),
        ),
        (
          title: 'Fonts',
          icon: Icons.font_download_outlined,
          content: _fonts(settings),
        ),
        (
          title: 'Font size',
          icon: Icons.format_size,
          content: _fontSize(settings),
        ),
        (
          title: 'Appearance',
          icon: Icons.palette_outlined,
          content: _appearance(settings),
        ),
      ];

  Widget _apiKey(SettingsState settings) {
    final theme = Theme.of(context);
    final fromEnv = settings.apiKeyFromEnvironment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabelValueRow(
          label: 'Status',
          trailing: StatusChip(
            fromEnv
                ? 'From environment'
                : settings.hasApiKey
                    ? 'Configured'
                    : 'Missing',
            color: settings.hasApiKey
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
        ),
        if (fromEnv) ...[
          const SizedBox(height: 12),
          InfoBanner(
            title: 'Loaded from environment',
            message: 'This key was read from the '
                '${settings.apiKeyEnvVarName} environment variable for this '
                'session. Edit and Save to store a key on this device instead; '
                'Clear reverts to the environment value.',
          ),
        ],
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
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
            if (settings.hasApiKey)
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(settingsProvider.notifier).clearApiKey();
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

  Widget _defaultModel(SettingsState settings) {
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
              ref.read(settingsProvider.notifier).setDefaultModel(selected.id);
            }
          },
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Change model'),
        ),
      ],
    );
  }

  /// Custom display names shown on chat bubbles. Empty fields fall back to
  /// "You" and the conversation's model name respectively.
  Widget _names(SettingsState settings) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _userNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'You',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => ref.read(settingsProvider.notifier).setUserName(v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _aiNameController,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'AI name',
            hintText: 'Model name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => ref.read(settingsProvider.notifier).setAiName(v),
        ),
        const SizedBox(height: 8),
        Text(
          'Shown on chat messages. Leave blank to use "You" and the '
          "conversation's model name.",
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  Widget _appearance(SettingsState settings) {
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
          onSelectionChanged: (s) {
            ref.read(settingsProvider.notifier).setThemeMode(s.first);
            _flashSaved();
          },
        ),
        const SizedBox(height: 16),
        Text('ACCENT COLOR', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 10),
        _AccentColorPicker(
          selected: settings.seedColor,
          onChanged: (c) {
            ref.read(settingsProvider.notifier).setSeedColor(c);
            _flashSaved();
          },
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          value: settings.reduceMotion,
          onChanged: (v) {
            ref.read(settingsProvider.notifier).setReduceMotion(v);
            _flashSaved();
          },
          title: const Text('Reduce motion'),
          subtitle: const Text(
            'Shortens or disables animations across the app.',
          ),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          value: settings.animateModelIndicator,
          onChanged: (v) {
            ref.read(settingsProvider.notifier).setAnimateModelIndicator(v);
            _flashSaved();
          },
          title: const Text('Show activity indicator while replying'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          value: settings.continuousModelBorder,
          onChanged: (v) {
            ref.read(settingsProvider.notifier).setContinuousModelBorder(v);
            _flashSaved();
          },
          title: const Text('Continuously animate the model border'),
          subtitle: const Text(
            'Off: the border animates once when you pick a model.',
          ),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          value: settings.replyCompleteFeedback,
          onChanged: (v) {
            ref.read(settingsProvider.notifier).setReplyCompleteFeedback(v);
            _flashSaved();
          },
          title: const Text('Feedback when a reply finishes'),
          subtitle: const Text(
            'A haptic buzz on mobile, or a short sound on desktop.',
          ),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _downloads(SettingsState settings) {
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
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () async {
                final dir = await const DownloadService().chooseDirectory();
                if (dir != null && mounted) {
                  ref.read(settingsProvider.notifier).setDownloadDir(dir);
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose folder'),
            ),
            if (settings.downloadDir != null)
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(settingsProvider.notifier).setDownloadDir(null),
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _fonts(SettingsState settings) {
    final read = ref.read(settingsProvider.notifier);
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
        _FontRow(
          label: 'Code / JSON',
          value: settings.monoFont,
          onChanged: read.setMonoFont,
          monoOnly: true,
        ),
      ],
    );
  }

  Widget _fontSize(SettingsState settings) {
    final read = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SizeRow(
          label: 'Your text',
          value: settings.userFontScale,
          onChanged: read.setUserFontScale,
        ),
        _SizeRow(
          label: 'Model output',
          value: settings.modelFontScale,
          onChanged: read.setModelFontScale,
        ),
        const SizedBox(height: 6),
        Text(
          'Scales the text size of your prompts and the model’s replies.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
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
    this.monoOnly = false,
  });

  final String label;
  final AppFont value;
  final ValueChanged<AppFont> onChanged;

  /// When true, only monospace fonts are offered (for the code/JSON picker).
  final bool monoOnly;

  /// Fonts listed alphabetically by display name.
  static final List<AppFont> _sortedFonts = AppFont.values.toList()
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  static final List<AppFont> _sortedMonoFonts = AppFontX.monoFonts
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
              for (final f in (monoOnly ? _sortedMonoFonts : _sortedFonts))
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

/// A named text-size option mapped to a scale multiplier.
typedef _ScaleOption = ({String label, double scale});

const List<_ScaleOption> _fontScales = [
  (label: 'Small', scale: 0.85),
  (label: 'Default', scale: 1.0),
  (label: 'Large', scale: 1.15),
  (label: 'Larger', scale: 1.3),
  (label: 'Largest', scale: 1.6),
];

/// A labelled text-size picker (compact dropdown of named sizes).
class _SizeRow extends StatelessWidget {
  const _SizeRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  /// Snap the stored scale to the nearest preset so the dropdown always has a
  /// matching value even if an old/clamped value drifts slightly.
  double get _nearest => _fontScales
      .map((o) => o.scale)
      .reduce((a, b) => (a - value).abs() <= (b - value).abs() ? a : b);

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
          DropdownButton<double>(
            value: _nearest,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            items: [
              for (final o in _fontScales)
                DropdownMenuItem(value: o.scale, child: Text(o.label)),
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

/// Curated accent-colour swatches plus a custom RGB picker. Both themes are
/// regenerated from the chosen colour.
class _AccentColorPicker extends StatelessWidget {
  const _AccentColorPicker({required this.selected, required this.onChanged});

  final Color selected;
  final ValueChanged<Color> onChanged;

  static const _presets = <Color>[
    Color(0xFF5A4FCF), // indigo (default)
    Color(0xFF7C3AED), // violet
    Color(0xFF2563EB), // blue
    Color(0xFF0891B2), // cyan
    Color(0xFF0D9488), // teal
    Color(0xFF16A34A), // green
    Color(0xFFCA8A04), // amber
    Color(0xFFEA580C), // orange
    Color(0xFFDC2626), // red
    Color(0xFFDB2777), // pink
    Color(0xFF475569), // slate
  ];

  @override
  Widget build(BuildContext context) {
    final sel = selected.toARGB32();
    final isPreset = _presets.any((c) => c.toARGB32() == sel);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in _presets)
          _ColorDot(
            color: c,
            selected: c.toARGB32() == sel,
            onTap: () => onChanged(c),
          ),
        _CustomColorDot(
          selected: !isPreset,
          current: selected,
          onPicked: onChanged,
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

/// Rainbow swatch that opens a dialog to choose any colour.
class _CustomColorDot extends StatelessWidget {
  const _CustomColorDot({
    required this.selected,
    required this.current,
    required this.onPicked,
  });

  final bool selected;
  final Color current;
  final ValueChanged<Color> onPicked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: () async {
        final start = selected ? current : scheme.primary;
        final picked = await showColorPickerDialog(
          context,
          start,
          title: Text('Accent colour',
              style: Theme.of(context).textTheme.titleMedium),
          pickersEnabled: const {
            ColorPickerType.primary: true,
            ColorPickerType.accent: true,
            ColorPickerType.wheel: true,
          },
          enableShadesSelection: true,
          showColorCode: true,
          colorCodeHasColor: true,
          constraints: const BoxConstraints(
              minHeight: 480, minWidth: 320, maxWidth: 360),
        );
        onPicked(picked);
      },
      radius: 26,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(colors: [
            Color(0xFFEF4444),
            Color(0xFFEAB308),
            Color(0xFF22C55E),
            Color(0xFF06B6D4),
            Color(0xFF6366F1),
            Color(0xFFEC4899),
            Color(0xFFEF4444),
          ]),
          border: Border.all(
            color: selected ? scheme.onSurface : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: Icon(selected ? Icons.check : Icons.tune,
            color: Colors.white, size: 20),
      ),
    );
  }
}
