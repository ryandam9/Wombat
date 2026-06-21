import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class ModelSelector extends ConsumerStatefulWidget {
  const ModelSelector({super.key});

  @override
  ConsumerState<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends ConsumerState<ModelSelector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  String? _lastModelId;
  bool _wasSpinning = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Drives the border animation. The border spins continuously while the model
  /// is **responding** (a clear, glanceable "working" cue around the model) or
  /// when the continuous-border setting is on; otherwise it sweeps once on a
  /// model change and settles. Safe to call on every build — it only acts when
  /// something relevant changed.
  void _syncAnimation(
      String modelId, bool continuous, bool responding, bool reduce) {
    final modelChanged = modelId != _lastModelId;
    _lastModelId = modelId;

    // Reduced motion: keep the border static.
    if (reduce) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 0;
      _wasSpinning = false;
      return;
    }

    final spin = continuous || responding;
    if (spin) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      // Just stopped spinning (e.g. the reply finished): settle the border.
      if (_wasSpinning) {
        _controller.stop();
        _controller.value = 0;
      }
      // Sweep once to acknowledge a model change.
      if (modelChanged) _controller.forward(from: 0);
    }
    _wasSpinning = spin;
  }

  Future<void> _openPicker() async {
    final selected = await Navigator.of(context).push<OpenRouterModel>(
      MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
    );
    if (selected != null && mounted) {
      ref.read(chatProvider.notifier).setModelForCurrent(
            selected.id,
            supportsImageOutput: selected.supportsImageOutput,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(chatProvider).current;
    final modelId = current?.modelId ?? '—';
    // A chat's model is fixed once it has started (has messages); the pill then
    // becomes a read-only label so the thread stays on one model.
    final locked = current != null && current.messages.isNotEmpty;
    final continuous =
        ref.watch(settingsProvider.select((s) => s.continuousModelBorder));
    final responding =
        ref.watch(chatProvider.select((c) => c.isResponding));
    _syncAnimation(modelId, continuous, responding,
        MediaQuery.of(context).disableAnimations);
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
    // A thicker, glowing border while the model works makes the activity
    // obvious around the pill; the resting border stays bold and chunky.
    final borderWidth = responding ? 2.6 : 2.0;

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
              boxShadow: responding
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.45),
                        blurRadius: 9,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
            padding: EdgeInsets.all(borderWidth),
            child: child,
          );
        },
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(radius - borderWidth),
          clipBehavior: Clip.antiAlias,
          child: Tooltip(
            message: locked
                ? 'This chat is using $modelId.\n'
                    'Start a new chat to use a different model.'
                : 'Change model',
            child: InkWell(
              // Locked once the chat has started, so the model can't change
              // mid-thread.
              onTap: locked ? null : _openPicker,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      locked ? Icons.lock_outline : Icons.smart_toy_outlined,
                      size: 18,
                      color: locked ? scheme.onSurfaceVariant : scheme.primary,
                    ),
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
      ),
    );
  }
}
