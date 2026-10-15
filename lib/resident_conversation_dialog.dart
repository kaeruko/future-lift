import 'package:flutter/material.dart';

import 'dialogue_engine.dart';
import 'resident_collection.dart';

/// Shows one speaker at a time. The dialogue and its reply share one
/// conversation; advancing never selects a new dialogue or modifies progress.
class ResidentConversationDialog extends StatefulWidget {
  const ResidentConversationDialog({
    super.key,
    required this.speaker,
    required this.dialogue,
  });

  final TownResident speaker;
  final DialogueEntry dialogue;

  @override
  State<ResidentConversationDialog> createState() =>
      _ResidentConversationDialogState();
}

class _ResidentConversationDialogState
    extends State<ResidentConversationDialog> {
  int _turnIndex = 0;

  void _advance(int turnCount) {
    if (_turnIndex + 1 >= turnCount) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _turnIndex++);
  }

  @override
  Widget build(BuildContext context) {
    final reply = widget.dialogue.reply;
    final turns = [
      (speaker: widget.speaker, text: widget.dialogue.text),
      if (reply != null)
        (speaker: TownResident.fromId(reply.residentId), text: reply.text),
    ];
    final turn = turns[_turnIndex];
    final hasNext = _turnIndex < turns.length - 1;

    // In addition to the visible button, tapping anywhere inside the dialog
    // advances a turn. A tap on the button is handled by the inner control.
    return GestureDetector(
      onTap: () => _advance(turns.length),
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: Row(
          children: [
            TownResidentAvatar(resident: turn.speaker, size: 48),
            const SizedBox(width: 12),
            Expanded(child: Text(turn.speaker.label)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                turn.text,
                key: const ValueKey('dialogue-visible-line'),
                style: const TextStyle(fontSize: 19, height: 1.8),
              ),
              if (turns.length > 1) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_turnIndex + 1} / ${turns.length}',
                    key: const ValueKey('dialogue-turn-count'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('dialogue-next-button'),
            onPressed: () => _advance(turns.length),
            child: Text(hasNext ? 'つづきへ' : 'また話そう'),
          ),
        ],
      ),
    );
  }
}
