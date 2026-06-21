import 'package:flutter/material.dart';

/// A help & troubleshooting guide. Topics are grouped into sections and shown
/// collapsed by default — each shows a short summary and expands on tap to
/// reveal the full details.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Troubleshoot')),
      body: const _ResponsiveSections(
        children: [
          _Section(
            title: 'Voice & audio',
            items: [
              _HelpTopic(
                icon: Icons.mic_none,
                title: 'How voice messages work',
                summary: 'Recordings are sent to the model as audio — not '
                    'saved as an mp3.',
                detail: _VoiceMessagesDetail(),
              ),
              _HelpTopic(
                icon: Icons.mic_off_outlined,
                title: 'The mic button does nothing / recording fails',
                summary: 'Check microphone permission and your audio server.',
                detail: _Paragraph(
                  'Grant the microphone permission when prompted. On Linux, '
                  'make sure your audio server (PulseAudio / PipeWire) is '
                  'running so the mic can be captured.',
                ),
              ),
              _HelpTopic(
                icon: Icons.hearing_disabled,
                title: 'My voice clip was ignored or returned an error',
                summary: 'The selected model must accept audio input.',
                detail: _Paragraph(
                  'Pick a model that accepts audio input (e.g. '
                  'openai/gpt-4o-audio-preview, or an audio-capable Gemini '
                  'model). Text-only models cannot process audio attachments.',
                ),
              ),
            ],
          ),
          _Section(
            title: 'Models & usage',
            items: [
              _HelpTopic(
                icon: Icons.compare_arrows,
                title: 'Comparing models',
                summary: 'Run one prompt against several models side by side.',
                detail: _Paragraph(
                  'Open "Compare models" from the sidebar, add up to five '
                  'models, type a prompt and Run. Replies stream in side by '
                  'side. The session is preserved if you navigate away and '
                  'come back, and the Debug button shows the underlying API '
                  'sessions for each model.',
                ),
              ),
              _HelpTopic(
                icon: Icons.cloud_off_outlined,
                title: "Models won't load",
                summary: 'Usually an invalid key or no network.',
                detail: _Paragraph(
                  'Check that your API key is valid and you have network '
                  'access, then tap Retry in the model picker.',
                ),
              ),
              _HelpTopic(
                icon: Icons.insights_outlined,
                title: 'Usage & cost tracking',
                summary: 'Per-session tokens and USD cost from each response.',
                detail: _Paragraph(
                  'OpenRouter returns exact token counts and the USD cost of '
                  'each request; the app accumulates these for the current '
                  'session (in memory, reset on restart). Open the usage panel '
                  'from the chat header to see totals and a per-model '
                  'breakdown.',
                ),
              ),
              _HelpTopic(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Account balance shows "BALANCE UNAVAILABLE"',
                summary: 'The credits endpoint can require a privileged key.',
                detail: _Paragraph(
                  'If your inference key lacks credit-read permission the '
                  'balance is hidden, but per-session token and cost tracking '
                  'still works.',
                ),
              ),
            ],
          ),
          _Section(
            title: 'Setup, privacy & data',
            items: [
              _HelpTopic(
                icon: Icons.key_outlined,
                title: 'Adding your OpenRouter API key',
                summary: 'Stored on-device; sent only to OpenRouter.',
                detail: _Paragraph(
                  'Open Settings and save a valid key from openrouter.ai/keys. '
                  'It is kept in the platform secure store (Android Keystore / '
                  'Linux libsecret) and sent only to OpenRouter — never to any '
                  'server of ours.',
                ),
              ),
              _HelpTopic(
                icon: Icons.storage_outlined,
                title: 'Where is my data stored?',
                summary: 'Conversations live on your device in a local '
                    'database.',
                detail: _Paragraph(
                  'Conversations and messages are saved on-device in a local '
                  'SQLite database, and attachment bytes are kept as files on '
                  'disk — both survive restarts. Requests go straight from '
                  'your device to OpenRouter; nothing is proxied through a '
                  'server of ours.',
                ),
              ),
              _HelpTopic(
                icon: Icons.palette_outlined,
                title: 'Customizing the theme',
                summary: 'System / Light / Dark, plus a custom accent colour.',
                detail: _Paragraph(
                  'Choose the theme mode in Settings → Appearance. You can '
                  'also pick a custom accent colour, which reseeds the whole '
                  'light and dark palette.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lays the help sections in multiple columns on wide screens (so the desktop
/// view doesn't leave most of the width empty) and a single column when narrow.
class _ResponsiveSections extends StatelessWidget {
  const _ResponsiveSections({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.fromLTRB(16, 8, 16, 24);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 3
            : (constraints.maxWidth >= 720 ? 2 : 1);
        if (cols == 1) {
          return ListView(
            padding: pad,
            children: [
              for (final s in children)
                Padding(padding: const EdgeInsets.only(bottom: 20), child: s),
            ],
          );
        }
        // Distribute the sections into contiguous, balanced columns so the
        // reading order (top-to-bottom, then left-to-right) matches the single
        // mobile column — the page shows the same content in the same order on
        // desktop and mobile, only the number of columns changes. (Round-robin
        // would scatter the sections and reorder them per breakpoint.)
        final perColumn = (children.length / cols).ceil();
        final columns = List.generate(cols, (c) {
          final start = c * perColumn;
          final end = (start + perColumn).clamp(0, children.length);
          return [
            for (var i = start; i < end; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: children[i],
              ),
          ];
        });
        return SingleChildScrollView(
          padding: pad,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cols; i++) ...[
                if (i > 0) const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: columns[i],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A titled group of collapsible help topics.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<_HelpTopic> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1.2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        for (final item in items) ...[
          item,
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// A single collapsible help entry: icon + title + one-line summary, expanding
/// to reveal [detail].
class _HelpTopic extends StatelessWidget {
  const _HelpTopic({
    required this.icon,
    required this.title,
    required this.summary,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String summary;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        // Remove ExpansionTile's default top/bottom divider lines.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            summary,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [detail],
        ),
      ),
    );
  }
}

/// Plain body text for a help topic.
class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// The detailed, multi-part explanation of how a recorded voice clip is
/// handled end to end.
class _VoiceMessagesDetail extends StatelessWidget {
  const _VoiceMessagesDetail();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap the mic in the composer to record a clip. It is sent to the '
          'model as audio — it is not saved as an mp3. Here is exactly what '
          'happens to a recording:',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        const _Step(
          number: 1,
          title: 'Capture',
          body: 'Raw 16-bit PCM from the mic is buffered in memory and '
              'wrapped into a WAV (audio/wav). Nothing is written to a local '
              'temp file during capture.',
        ),
        const _Step(
          number: 2,
          title: 'Attachment',
          body: 'It becomes a message attachment held as base64 bytes in '
              'memory, shown as a chip in the composer.',
        ),
        const _Step(
          number: 3,
          title: 'Send',
          body: 'On Send it is attached to your message and sent inline in '
              'the request body, base64-encoded, straight from your device to '
              'OpenRouter — no server of our own in between:',
        ),
        const SizedBox(height: 8),
        const _CodeBlock(
          '{\n'
          '  "type": "input_audio",\n'
          '  "input_audio": {\n'
          '    "data": "<base64 WAV>",\n'
          '    "format": "wav"\n'
          '  }\n'
          '}',
        ),
        const SizedBox(height: 12),
        const _Step(
          number: 4,
          title: 'Persistence',
          body: 'The clip is stored as a file on disk (with its metadata in '
              'the local database), so it survives restarts. It is not a '
              'standalone .wav/.mp3 in your file manager — though you can '
              'export it to a .wav with the Save button on the attachment.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber,
                  size: 20, color: theme.colorScheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The model must support audio input',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'OpenRouter only forwards audio to models that accept it '
                      '(e.g. openai/gpt-4o-audio-preview, some Gemini models). '
                      'If the selected model does not support audio, the '
                      'request errors or the audio is ignored. We send WAV, '
                      'one of the two formats OpenRouter accepts (wav / mp3).',
                      style: TextStyle(
                          color: theme.colorScheme.onTertiaryContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A numbered step in a how-it-works list.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              '$number',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A monospace, bordered code block.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: SelectableText(
        code,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurface,
          height: 1.4,
        ),
      ),
    );
  }
}
