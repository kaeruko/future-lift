import 'package:flutter/material.dart';

import 'home_skin.dart';
import 'progress.dart';

/// Debug-only controls. Never calls ProgressController.complete or save.
class DebugMenuScreen extends StatelessWidget {
  const DebugMenuScreen({
    super.key,
    required this.progress,
    required this.selectedMission,
    required this.onMissionChanged,
    required this.onPreview,
    required this.busy,
  });

  final Progress progress;
  final Mission selectedMission;
  final ValueChanged<Mission> onMissionChanged;
  final VoidCallback onPreview;
  final bool busy;

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
                  '\nポイント・達成状況・履歴は変わりません。',
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
                const SizedBox(height: 12),
                Text(
                  '現在の社会貢献：${progress.points} pt（再生しても加算されません）',
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
