import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/openrouter_model.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/model_picker_screen.dart';

/// A compact pill showing the current conversation's model that opens the model
/// picker when tapped. The pill is wrapped in a gradient border so the selected
/// model stands out in the header.
///
/// By default the border sweeps once whenever a new model is selected and then
/// settles, so it isn't distracting. When [SettingsProvider.continuousModelBorder]
/// is on, the border spins continuously instead.
class ModelSelector extends StatefulWidget {
  const ModelSelector({super.key});

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  String? _lastModelId;
  bool? _lastContinuous;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Drives the border animation in response to model changes and the
  /// continuous-animation setting. Safe to call on every build: it only acts
  /// when something relevant actually changed.
  void _syncAnimation(String modelId, bool continuous) {
    final modelChanged = modelId != _lastModelId;
    final continuousChanged = continuous != _lastContinuous;
    _lastModelId = modelId;
    _lastContinuous = continuous;

    if (continuous) {
      // Start (or keep) the endless spin.
      if (continuousChanged || !_controller.isAnimating) _controller.repeat();
    } else {
      // Stop spinning if we just turned it off; sweep once on a model change.
      if (continuousChanged) _controller.stop();
      if (modelChanged || continuousChanged) _controller.forward(from: 0);
    }
  }

  Future<void> _openPicker() async {
    final selected = await Navigator.of(context).push<OpenRouterModel>(
      MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
    );
    if (selected != null && mounted) {
      context.read<ChatProvider>().setModelForCurrent(
            selected.id,
            supportsImageOutput: selected.supportsImageOutput,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final modelId = chat.current?.modelId ?? '—';
    final continuous = context
        .select<SettingsProvider, bool>((s) => s.continuousModelBorder);
    _syncAnimation(modelId, continuous);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Multi-stop sweep so the border reads as a continuous moving glow.
    final colors = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.primary,
    ];

    const radius = 22.0;

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: SweepGradient(
                colors: colors,
                transform:
                    GradientRotation(_controller.value * 2 * math.pi),
              ),
            ),
            padding: const EdgeInsets.all(1.6),
            child: child,
          );
        },
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(radius - 1.6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        modelId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
