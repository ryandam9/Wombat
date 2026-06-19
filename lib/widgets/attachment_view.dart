import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/attachment.dart';

/// Renders a single [MessageAttachment]: an inline image, an audio player, or
/// a document chip.
class AttachmentView extends StatelessWidget {
  const AttachmentView({super.key, required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    switch (attachment.kind) {
      case AttachmentKind.image:
        return _ImageAttachment(attachment: attachment);
      case AttachmentKind.audio:
        return AudioPlayerBar(attachment: attachment);
      case AttachmentKind.file:
        return _FileAttachment(attachment: attachment);
    }
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            child: Image.memory(attachment.bytes, fit: BoxFit.contain),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          attachment.bytes,
          width: 260,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _BrokenAttachment(label: 'image'),
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPdf = attachment.mimeType.contains('pdf');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPdf ? Icons.picture_as_pdf : Icons.description, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              attachment.name ?? 'document',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrokenAttachment extends StatelessWidget {
  const _BrokenAttachment({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 18),
          const SizedBox(width: 6),
          Text('Could not display $label'),
        ],
      ),
    );
  }
}

/// A compact play/pause + seek bar for an audio attachment, backed by
/// [audioplayers]. Plays the bytes directly from memory.
class AudioPlayerBar extends StatefulWidget {
  const AudioPlayerBar({super.key, required this.attachment});

  final MessageAttachment attachment;

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.play(BytesSource(
          widget.attachment.bytes,
          mimeType: widget.attachment.mimeType,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio playback failed: $e')),
        );
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = _duration.inMilliseconds.toDouble();
    final value = _position.inMilliseconds.clamp(0, max.toInt()).toDouble();

    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
            onPressed: _toggle,
          ),
          Expanded(
            child: Slider(
              value: max <= 0 ? 0 : value,
              max: max <= 0 ? 1 : max,
              onChanged: max <= 0
                  ? null
                  : (v) => _player.seek(Duration(milliseconds: v.round())),
            ),
          ),
          Text(_fmt(_duration == Duration.zero ? _position : _duration),
              style: theme.textTheme.labelSmall),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
