import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../widgets/pressable_scale.dart';

/// A short, three-page Neo Brutalist welcome shown only on first launch.
/// Calls [onDone] when the user finishes or skips.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <_IntroPage>[
    _IntroPage(
      accent: WombatColors.clay,
      image: 'assets/icon/app_icon.png',
      icon: Icons.pets,
      title: 'Welcome to Wombat',
      body: 'One key, every model. Chat with the best LLMs through your '
          'OpenRouter account — no extra accounts to juggle.',
    ),
    _IntroPage(
      accent: WombatColors.skyBlue,
      icon: Icons.grid_view_rounded,
      title: 'Hundreds of models',
      body: 'Browse, search and switch models anytime — or run one prompt '
          'across several side by side and compare the answers.',
    ),
    _IntroPage(
      accent: WombatColors.eucalyptus,
      icon: Icons.lock_outline_rounded,
      title: 'Private by design',
      body: 'Your chats and key stay on your device. Add your OpenRouter key '
          'in Settings and start your first conversation.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _pages.length - 1;

  void _next() {
    if (_isLast) {
      widget.onDone();
    } else {
      _controller.nextPage(
        duration: AppTokens.durMed,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip, top-right.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                child: AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: AppTokens.durFast,
                  child: TextButton(
                    onPressed: _isLast ? null : widget.onDone,
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _IntroPageView(page: _pages[i]),
              ),
            ),
            // Page indicator.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: AppTokens.durFast,
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 26 : 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: i == _page ? scheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: scheme.outline, width: AppTokens.border),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Primary action.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PressableScale(
                mode: PressMode.neo,
                shadowOffset: AppTokens.shadowMd,
                borderRadius: AppTokens.radiusMd,
                child: Material(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _next,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMd),
                        border: Border.all(
                            color: scheme.outline, width: AppTokens.borderThick),
                      ),
                      child: Text(
                        _isLast ? 'Get started' : 'Next',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage {
  const _IntroPage({
    required this.accent,
    required this.icon,
    required this.title,
    required this.body,
    this.image,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String body;
  final String? image;
}

class _IntroPageView extends StatelessWidget {
  const _IntroPageView({required this.page});

  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onAccent =
        page.accent.computeLuminance() > 0.5 ? WombatColors.ink : WombatColors.cream;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A chunky, slightly-tilted accent block holds the icon/art.
              Transform.rotate(
                angle: -0.04,
                child: Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: page.accent,
                    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                    border: Border.all(
                        color: scheme.outline, width: AppTokens.borderThick),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow,
                        offset: AppTokens.shadowLg,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: page.image != null
                      ? Image.asset(
                          page.image!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(page.icon, size: 56, color: onAccent),
                        )
                      : Icon(page.icon, size: 56, color: onAccent),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                page.body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
