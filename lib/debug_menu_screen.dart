import 'package:flutter/material.dart';

import 'home_skin.dart';
import 'progress.dart';

/// Debug-only controls for testing celebrations, tickets and resets.
class DebugMenuScreen extends StatelessWidget {
  const DebugMenuScreen({
    super.key,
    required this.progress,
    required this.selectedMission,
    required this.onMissionChanged,
    required this.onPreview,
    required this.onResetAll,
    required this.onAddTickets,
    required this.busy,
  });

  final Progress progress;
  final Mission selectedMission;
  final ValueChanged<Mission> onMissionChanged;
  final VoidCallback onPreview;
  final Future<bool> Function() onResetAll;
  final Future<bool> Function(int) onAddTickets;
  final bool busy;

  Future<void> _addTickets(BuildContext context, int amount) async {
    if (busy) return;
    final succeeded = await onAddTickets(amount);
    if (!context.mounted || !succeeded) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ガチャ券を$amount枚追加しました')),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    if (busy) return;
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('全ミッションをリセットしますか？'),
        content: const Text(
          'デイリー・ウィークリー・マンスリーの達成状態を'
          'すべて未達成に戻します。\n\n'
          'ことほぎと達成履歴は残ります。'
          'もう一度「できた！」を押すと、ことほぎが再び加算されます。'
          '\n\n※ 開発・動作確認用の機能です。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const ValueKey('debug-confirm-reset-missions'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('全ミッションをリセット'),
          ),
        ],
      ),
    );
    if (!context.mounted || shouldReset != true) return;
    final succeeded = await onResetAll();
    if (!context.mounted || !succeeded) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('全ミッションの達成状態をリセットしました')),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Image.asset(
          'assets/kotohogu/town_background.png',
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
      ),
      ListView(
        key: const ValueKey('debug-menu-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: parchment(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    uiPart('21_nav_menu', width: 55, height: 55),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'メニュー',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: wood,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '開発用・お祝い演出の確認',
                  style: TextStyle(
                    color: wood,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  '拍手と「ありがとうを受け取る」を何度でも試せます。'
                  '\nことほぎ・達成状況・履歴は変わりません。',
                  style: TextStyle(color: wood, height: 1.65),
                ),
                const SizedBox(height: 18),
                const Text(
                  '表示するミッション',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: wood,
                  ),
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFFFFAEE),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Mission>(
                      key: const ValueKey('debug-preview-mission'),
                      isExpanded: true,
                      value: selectedMission,
                      onChanged: busy
                          ? null
                          : (mission) {
                              if (mission != null) onMissionChanged(mission);
                            },
                      items: [
                        for (final mission in Mission.values)
                          DropdownMenuItem<Mission>(
                            value: mission,
                            child: Text(
                              mission.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('debug-replay-celebration'),
                    onPressed: busy ? null : onPreview,
                    icon: const Icon(Icons.celebration_rounded),
                    label: const Text('もう一度ありがとうを受け取る'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB94219),
                      foregroundColor: const Color(0xFFFFF7DD),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'ガチャ券の追加',
                  style: TextStyle(
                    color: wood,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '現在のガチャ券：${progress.residents.tickets(progress.points)}枚',
                  key: const ValueKey('debug-ticket-count'),
                  style: const TextStyle(color: wood),
                ),
                const SizedBox(height: 6),
                const Text(
                  '演出の動作確認用です。ことほぎや達成履歴は変わりません。',
                  style: TextStyle(color: wood, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('debug-add-ticket-1'),
                      onPressed: busy ? null : () => _addTickets(context, 1),
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: const Text('ガチャ券 +1枚'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('debug-add-ticket-10'),
                      onPressed: busy ? null : () => _addTickets(context, 10),
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: const Text('ガチャ券 +10枚'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'ミッション達成状態のリセット',
                  style: TextStyle(
                    color: wood,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '今日・今週・今月の達成を未達成に戻します。'
                  '\nことほぎやこれまでの履歴は残ります。',
                  style: TextStyle(color: wood, height: 1.6),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('debug-reset-all-missions'),
                    onPressed: busy ? null : () => _confirmReset(context),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('全ミッションをリセット'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9C351C),
                      side: const BorderSide(color: Color(0xFF9C351C)),
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '所持ことほぎ：${progress.residents.availableKotohogi(progress.points)}（再生しても加算されません）',
                  key: const ValueKey('debug-current-points'),
                  style: const TextStyle(color: wood, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}
