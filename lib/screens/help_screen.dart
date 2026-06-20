import 'package:flutter/material.dart';

import '../widgets/ui_kit.dart';

/// A static help page explaining how some of the less-obvious features work
/// (e.g. what happens to a recorded voice clip) plus common troubleshooting.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Troubleshoot')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _VoiceMessagesSection(),
          SizedBox(height: 16),
          _TroubleshootingSection(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _VoiceMessagesSection extends StatelessWidget {
  const _VoiceMessagesSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionPanel(
      title: 'How voice messages work',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tap the mic in the composer to record a clip. It is sent to the '
            'model as audio — it is not saved as an mp3. Here is exactly what '
            'happens to a recording:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
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
                'the request body, base64-encoded, straight from your device '
                'to OpenRouter — no server of our own in between:',
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
            body: 'The clip is stored as base64 inside the conversation on '
                'disk, so it survives restarts. It is not a standalone '
                '.wav/.mp3 file — though you can export it to a .wav with the '
                'Save button on the attachment.',
          ),
          const SizedBox(height: 8),
          const InfoBanner(
            kind: BannerKind.warning,
            title: 'The model must support audio input',
            message: 'OpenRouter only forwards audio to models that accept it '
                '(e.g. openai/gpt-4o-audio-preview, some Gemini models). If the '
                'selected model does not support audio, the request errors or '
                'the audio is ignored. We send WAV, which is one of the two '
                'formats OpenRouter accepts (wav / mp3).',
          ),
        ],
      ),
    );
  }
}

class _TroubleshootingSection extends StatelessWidget {
  const _TroubleshootingSection();

  @override
  Widget build(BuildContext context) {
    return const SectionPanel(
      title: 'Troubleshooting',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Faq(
            question: 'The mic button does nothing / recording fails',
            answer: 'Grant the microphone permission when prompted. On Linux, '
                'make sure your audio server (PulseAudio / PipeWire) is running '
                'so the mic can be captured.',
          ),
          _FaqDivider(),
          _Faq(
            question: 'My voice clip was ignored or returned an error',
            answer: 'Pick a model that accepts audio input (e.g. '
                'openai/gpt-4o-audio-preview, or an audio-capable Gemini '
                'model). Text-only models cannot process audio attachments.',
          ),
          _FaqDivider(),
          _Faq(
            question: '"Add your OpenRouter API key in Settings first."',
            answer: 'Open Settings and save a valid key from '
                'openrouter.ai/keys. It is stored in the device secure store '
                'and sent only to OpenRouter.',
          ),
          _FaqDivider(),
          _Faq(
            question: 'Models won\'t load',
            answer: 'Check that your API key is valid and you have network '
                'access, then tap Retry in the model picker.',
          ),
          _FaqDivider(),
          _Faq(
            question: 'Account balance shows "BALANCE UNAVAILABLE"',
            answer: 'The credits endpoint can require a privileged key. If your '
                'inference key lacks that permission the balance is hidden, but '
                'per-session token and cost tracking still works.',
          ),
        ],
      ),
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

/// A question/answer pair.
class _Faq extends StatelessWidget {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.help_outline,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(question,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(answer, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _FaqDivider extends StatelessWidget {
  const _FaqDivider();

  @override
  Widget build(BuildContext context) => const Divider(height: 1);
}
