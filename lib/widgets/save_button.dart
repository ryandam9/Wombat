import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/download_service.dart';

/// A compact save control used on assistant text and attachments. Offers
/// "Save" (default folder, or dialog/share) and "Save as…" (always prompts).
class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
    required this.bytes,
    required this.baseName,
    required this.mimeType,
    this.compact = false,
  });

  /// Produces the bytes to save (lazily, so large data isn't decoded early).
  final List<int> Function() bytes;
  final String baseName;
  final String mimeType;

  /// When true, renders an icon-only button (for attachment overlays).
  final bool compact;

  static const _service = DownloadService();

  Future<void> _save(BuildContext context, {required bool forceDialog}) async {
    final messenger = ScaffoldMessenger.of(context);
    final dir = context.read<SettingsProvider>().downloadDir;
    final result = await _service.save(
      bytes: bytes(),
      baseName: baseName,
      mimeType: mimeType,
      defaultDir: dir,
      forceDialog: forceDialog,
    );
    if (result.outcome == SaveOutcome.cancelled) return;
    messenger.showSnackBar(
      SnackBar(content: Text(result.message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      tooltip: 'Save',
      icon: Icon(Icons.download_outlined, size: compact ? 18 : 20),
      padding: EdgeInsets.zero,
      onSelected: (forceDialog) => _save(context, forceDialog: forceDialog),
      itemBuilder: (_) => [
        const PopupMenuItem(value: false, child: Text('Save')),
        if (_service.isDesktop)
          const PopupMenuItem(value: true, child: Text('Save as…')),
      ],
    );
  }
}

/// Helper to turn a base64 string into a lazy byte producer for [SaveButton].
List<int> Function() base64Bytes(String data) => () => base64Decode(data);
