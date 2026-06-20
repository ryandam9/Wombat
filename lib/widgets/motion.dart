import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// Central place for animation durations so they can be shortened or disabled
/// when the user (or platform) asks for reduced motion.
///
/// Motion is reduced when either the **Reduce motion** setting is on or the
/// platform reports `MediaQuery.disableAnimations`.
class Motion {
  const Motion._(this.reduced);

  /// Whether motion should be reduced.
  final bool reduced;

  /// Resolves the effective motion preference from a [BuildContext] and the
  /// current settings.
  factory Motion.of(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingsProvider.select((s) => s.reduceMotion));
    final platform = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Motion._(setting || platform);
  }

  /// Like [Motion.of] but without a [WidgetRef] (reads the platform flag only).
  factory Motion.platform(BuildContext context, {bool setting = false}) {
    final platform = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Motion._(setting || platform);
  }

  /// Short interactions (button swaps, chips, attachment previews).
  Duration get fast =>
      reduced ? Duration.zero : const Duration(milliseconds: 180);

  /// Medium transitions (section/page crossfades, sidebar collapse).
  Duration get medium =>
      reduced ? Duration.zero : const Duration(milliseconds: 280);

  /// Data-visualisation transitions (charts).
  Duration get chart =>
      reduced ? Duration.zero : const Duration(milliseconds: 420);

  /// Scales an arbitrary [duration] to zero when motion is reduced.
  Duration scale(Duration duration) => reduced ? Duration.zero : duration;
}
