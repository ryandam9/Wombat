import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/attachment.dart';
import '../providers/chat_provider.dart';

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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecorder _recorder = AudioRecorder();
  final List<MessageAttachment> _attachments = [];
  bool _recording = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    super.dispose();
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
        final path = await _recorder.stop();
        setState(() => _recording = false);
        if (path == null) return;
        final bytes = await File(path).readAsBytes();
        setState(() {
          _attachments.add(MessageAttachment.fromBytes(
            kind: AttachmentKind.audio,
            mimeType: 'audio/wav',
            bytes: bytes,
            name: 'recording.wav',
          ));
        });
      } else {
        if (!await _recorder.hasPermission()) {
          _toast('Microphone permission denied.');
          return;
        }
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: path,
        );
        setState(() => _recording = true);
      }
    } catch (e) {
      setState(() => _recording = false);
      _toast('Recording failed: $e');
    }
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachments.isNotEmpty) _AttachmentPreviews(
              attachments: _attachments,
              onRemove: (i) => setState(() => _attachments.removeAt(i)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AttachMenu(onPick: _pick),
                IconButton(
                  tooltip: _recording ? 'Stop recording' : 'Record audio',
                  icon: Icon(_recording ? Icons.stop_circle : Icons.mic_none),
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
                        hintText: _recording
                            ? 'Recording…'
                            : 'Send a message…',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                isResponding
                    ? IconButton.filledTonal(
                        tooltip: 'Stop',
                        icon: const Icon(Icons.stop),
                        onPressed: () =>
                            ref.read(chatProvider.notifier).stopResponding(),
                      )
                    : IconButton.filled(
                        tooltip: 'Send',
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: _send,
                      ),
              ],
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
  const _AttachmentPreviews({required this.attachments, required this.onRemove});

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
