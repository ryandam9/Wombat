import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/openrouter_model.dart';
import '../providers/chat_provider.dart';
import '../screens/model_picker_screen.dart';

/// A compact button showing the current conversation's model that opens the
/// model picker when tapped.
class ModelSelector extends StatelessWidget {
  const ModelSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final modelId = chat.current?.modelId ?? '—';

    return ActionChip(
      avatar: const Icon(Icons.smart_toy_outlined, size: 18),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(
          modelId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      onPressed: () async {
        final selected = await Navigator.of(context).push<OpenRouterModel>(
          MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
        );
        if (selected != null && context.mounted) {
          context.read<ChatProvider>().setModelForCurrent(
                selected.id,
                supportsImageOutput: selected.supportsImageOutput,
              );
        }
      },
    );
  }
}
