import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../models/attachment.dart';
import '../providers/chat_provider.dart';
import '../services/attachment_limits.dart';
import '../services/wav.dart';
import '../theme/app_tokens.dart';
import 'motion.dart';
import 'pressable_scale.dart';

/// The message composer: attachment picker, in-app audio recorder, a growing
/// text field, attachment previews, and a send/stop button.
///
/// Enter sends; Shift+Enter inserts a newline.
class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  // Capture raw 16-bit PCM and assemble the WAV ourselves. This avoids the
  // record_linux file-encoder path (parecord -> ffmpeg pipe), which races on
  // stop ("StreamSink is bound to a stream") and needs ffmpeg installed.
  static const int _recordSampleRate = 16000;
  static const int _recordChannels = 1;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecorder _recorder = AudioRecorder();
  final List<MessageAttachment> _attachments = [];
  StreamSubscription<Uint8List>? _audioSub;
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  bool _recording = false;
  Timer? _recordTimer;
  Duration _recordElapsed = Duration.zero;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _audioSub?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _stopRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty && _attachments.isEmpty) return;
    final attachments = List<MessageAttachment>.from(_attachments);
    _controller.clear();
    setState(_attachments.clear);
    ref.read(chatProvider.notifier).sendMessage(text, attachments: attachments);
    _focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pick(AttachmentKind kind) async {
    try {
      final group = switch (kind) {
        AttachmentKind.image => const XTypeGroup(
            label: 'Images',
            extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
          ),
        AttachmentKind.audio => const XTypeGroup(
            label: 'Audio',
            extensions: ['wav', 'mp3'],
          ),
        AttachmentKind.file => const XTypeGroup(
            label: 'Documents',
            extensions: ['pdf'],
          ),
      };
      final file = await openFile(acceptedTypeGroups: [group]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final tooLarge = attachmentSizeError(kind, bytes.length);
      if (tooLarge != null) {
        _toast(tooLarge);
        return;
      }
      final mime = _mimeFor(kind, file.name);
      setState(() {
        _attachments.add(MessageAttachment.fromBytes(
          kind: kind,
          mimeType: mime,
          bytes: bytes,
          name: kind == AttachmentKind.file ? file.name : null,
        ));
      });
    } catch (e) {
      _toast('Could not attach file: $e');
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_recording) {
        await _stopRecording();
      } else {
        await _startRecording();
      }
    } catch (e) {
      await _cleanupRecording();
      _toast('Recording failed: $e');
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      _toast('Microphone permission denied.');
      return;
    }
    _pcm.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _recordSampleRate,
        numChannels: _recordChannels,
      ),
    );
    _audioSub = stream.listen(
      _pcm.add,
      onError: (Object e) {
        _cleanupRecording();
        _toast('Recording failed: $e');
      },
    );
    _recordElapsed = Duration.zero;
    _stopRecordTimer();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordElapsed += const Duration(seconds: 1));
      }
    });
    setState(() => _recording = true);
  }

  Future<void> _stopRecording() async {
    _stopRecordTimer();
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    setState(() => _recording = false);

    final pcm = _pcm.takeBytes();
    if (pcm.isEmpty) return;
    final wav = pcmToWav(
      pcm,
      sampleRate: _recordSampleRate,
      numChannels: _recordChannels,
    );
    setState(() {
      _attachments.add(MessageAttachment.fromBytes(
        kind: AttachmentKind.audio,
        mimeType: 'audio/wav',
        bytes: wav,
        name: 'recording.wav',
      ));
    });
  }

  /// Tears down an in-progress recording, discarding any captured audio.
  Future<void> _cleanupRecording() async {
    _stopRecordTimer();
    await _audioSub?.cancel();
    _audioSub = null;
    _pcm.clear();
    try {
      await _recorder.stop();
    } catch (_) {
      // Already stopped / never started.
    }
    if (mounted) setState(() => _recording = false);
  }

  String _mimeFor(AttachmentKind kind, String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (kind) {
      AttachmentKind.image => switch (ext) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'gif' => 'image/gif',
          'webp' => 'image/webp',
          _ => 'image/png',
        },
      AttachmentKind.audio => ext == 'mp3' ? 'audio/mpeg' : 'audio/wav',
      AttachmentKind.file => 'application/pdf',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isResponding =
        ref.watch(chatProvider.select((c) => c.isResponding));
    final motion = Motion.of(context, ref);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attachment previews grow/shrink the composer smoothly.
            AnimatedSize(
              duration: motion.resize,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: motion.fast,
                child: _attachments.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : _AttachmentPreviews(
                        key: ValueKey(_attachments.length),
                        attachments: _attachments,
                        onRemove: (i) =>
                            setState(() => _attachments.removeAt(i)),
                      ),
              ),
            ),
            // A recording pill with a timer and Cancel / Use actions.
            AnimatedSize(
              duration: motion.resize,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: motion.fast,
                child: _recording
                    ? Padding(
                        key: const ValueKey('recording'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RecordingPill(
                          elapsed: _recordElapsed,
                          onCancel: _cleanupRecording,
                          onUse: _stopRecording,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: AppTokens.border),
                boxShadow: AppTokens.softShadow(theme.colorScheme, level: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AttachMenu(onPick: _pick),
                    IconButton(
                      tooltip:
                          _recording ? 'Stop recording' : 'Record audio',
                      icon: Icon(
                          _recording ? Icons.stop_circle : Icons.mic_none),
                      color: _recording ? theme.colorScheme.error : null,
                      onPressed: _toggleRecording,
                    ),
                    Expanded(
                      child: Focus(
                        onKeyEvent: _onKey,
                        child: TextField(
                          controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          hintText: _recording
                              ? 'Recording…'
                              : 'Send a message…',
                          hintStyle: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant),
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PressableScale(
                    mode: PressMode.neo,
                    shadowOffset: AppTokens.shadowSm,
                    borderRadius: AppTokens.radiusMd,
                    child: AnimatedSwitcher(
                      duration: motion.fast,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(
                            opacity: animation, child: child),
                      ),
                      child: isResponding
                          ? _ComposerButton(
                              key: const ValueKey('stop'),
                              icon: Icons.stop,
                              tooltip: 'Stop',
                              tonal: true,
                              onPressed: () => ref
                                  .read(chatProvider.notifier)
                                  .stopResponding(),
                            )
                          : _ComposerButton(
                              key: const ValueKey('send'),
                              icon: Icons.arrow_upward,
                              tooltip: 'Send',
                              onPressed: _send,
                            ),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachMenu extends StatelessWidget {
  const _AttachMenu({required this.onPick});

  final void Function(AttachmentKind) onPick;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AttachmentKind>(
      tooltip: 'Attach',
      icon: const Icon(Icons.add_circle_outline),
      onSelected: onPick,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: AttachmentKind.image,
          child: ListTile(
            leading: Icon(Icons.image_outlined),
            title: Text('Image'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: AttachmentKind.audio,
          child: ListTile(
            leading: Icon(Icons.audiotrack),
            title: Text('Audio file'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: AttachmentKind.file,
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf),
            title: Text('Document (PDF)'),
            dense: true,
          ),
        ),
      ],
    );
  }
}

class _AttachmentPreviews extends StatelessWidget {
  const _AttachmentPreviews(
      {super.key, required this.attachments, required this.onRemove});

  final List<MessageAttachment> attachments;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < attachments.length; i++)
              Chip(
                avatar: Icon(_iconFor(attachments[i].kind), size: 18),
                label: Text(
                  _labelFor(attachments[i]),
                  overflow: TextOverflow.ellipsis,
                ),
                onDeleted: () => onRemove(i),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AttachmentKind kind) => switch (kind) {
        AttachmentKind.image => Icons.image_outlined,
        AttachmentKind.audio => Icons.audiotrack,
        AttachmentKind.file => Icons.picture_as_pdf,
      };

  String _labelFor(MessageAttachment a) => switch (a.kind) {
        AttachmentKind.image => 'Image',
        AttachmentKind.audio => a.name ?? 'Audio',
        AttachmentKind.file => a.name ?? 'Document',
      };
}

/// A recording status pill shown above the composer while capturing audio: a
/// pulsing red dot, the elapsed time, and Cancel / Use actions.
class _RecordingPill extends StatelessWidget {
  const _RecordingPill({
    required this.elapsed,
    required this.onCancel,
    required this.onUse,
  });

  final Duration elapsed;
  final VoidCallback onCancel;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(elapsed.inMinutes)}:${two(elapsed.inSeconds % 60)}';

    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Row(
          children: [
            _PulsingDot(color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text(
              'Recording $time',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
            const Spacer(),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
            const SizedBox(width: 4),
            FilledButton.tonal(onPressed: onUse, child: const Text('Use')),
          ],
        ),
      ),
    );
  }
}

/// A small dot that gently pulses to signal active recording.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Honour reduced motion: a static dot when animations are disabled.
    if (MediaQuery.of(context).disableAnimations) {
      return Icon(Icons.fiber_manual_record, size: 12, color: widget.color);
    }
    return ScaleTransition(
      scale: Tween(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: FadeTransition(
        opacity: Tween(begin: 0.4, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Icon(Icons.fiber_manual_record, size: 12, color: widget.color),
      ),
    );
  }
}

/// The composer send / stop control: a chunky bordered Neo button (thick ink
/// outline + hard offset shadow via the wrapping [PressableScale]) so it stays
/// clearly readable on any accent — including dark custom accents where the old
/// circular filled button blended in. [tonal] gives the Stop state a neutral
/// surface fill to distinguish it from the accent-filled Send.
class _ComposerButton extends StatelessWidget {
  const _ComposerButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tonal = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = tonal ? scheme.surfaceContainerHighest : scheme.primary;
    final fg = tonal ? scheme.onSurface : scheme.onPrimary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 50,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: scheme.outline, width: AppTokens.border),
            ),
            child: Icon(icon, size: 22, color: fg),
          ),
        ),
      ),
    );
  }
}
