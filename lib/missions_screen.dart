import 'package:flutter/material.dart';

import 'home_skin.dart';
import 'progress.dart';
import 'residents.dart';

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({
    super.key,
    required this.progress,
    required this.busy,
    required this.onComplete,
  });
  final Progress progress;
  final bool busy;
  final ValueChanged<Mission> onComplete;

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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          ContributionPanel(points: progress.points),
          const SizedBox(height: 20),
          Row(
            children: [
              const ResidentAvatar(
                resident: Resident.child,
                size: 68,
                celebrating: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            'ミッション一覧',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 6
                                ..color = const Color(0xFFFFF6D6),
                            ),
                          ),
                        ),
                        const Text(
                          'ミッション一覧',
                          style: TextStyle(
                            color: wood,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5DF),
                        border: Border.all(color: wood, width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '今日できたことを、教えてね。',
                        style: TextStyle(
                          color: wood,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                label: 'デイリー',
                selected: true,
                child: Image.asset(
                  'assets/quests/02_tab_daily_selected.png',
                  width: 142,
                  height: 53,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEEFFF5DF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${int.parse(progress.day.substring(5, 7))}月${int.parse(progress.day.substring(8))}日  •  ${progress.completed.length}/3 達成',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: wood,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF814E2C), Color(0xFF4B2C1D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: gold, width: 4),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xAA512B16),
                  offset: Offset(0, 4),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/quests/20_corner_left.png',
                    width: 56,
                    excludeFromSemantics: true,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/quests/19_corner_right.png',
                    width: 56,
                    excludeFromSemantics: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 42),
                  child: Column(
                    children: [
                      for (final mission in Mission.values)
                        _QuestCard(
                          mission: mission,
                          done: progress.completed.contains(mission),
                          onComplete: busy ? null : () => onComplete(mission),
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '量や回数は問いません。\n今日行動したことを、みんなで祝います。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFFE6B2),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.mission,
    required this.done,
    required this.onComplete,
  });
  final Mission mission;
  final bool done;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/quests/${mission == Mission.outside ? '13_mission_card_orange_empty_title' : '09_mission_card_gold_empty_title'}.png',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
        // The supplied card has baked currency/reward/challenge labels. An opaque
        // content layer preserves its decorative outer frame without showing them.
        Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: mission == Mission.outside
                    ? const [Color(0xFFFFD296), Color(0xFFFFF4D8)]
                    : const [Color(0xFFFFE7A3), Color(0xFFFFF7E4)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      switch (mission) {
                        Mission.strength => Icons.accessibility_new_rounded,
                        Mission.outside => Icons.directions_walk_rounded,
                        Mission.conversation => Icons.forum_rounded,
                      },
                      color: wood,
                      size: 30,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(
                              'assets/quests/10_label_bar_blank.png',
                            ),
                            fit: BoxFit.fill,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 8,
                        ),
                        child: Text(
                          mission.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: wood,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (done) uiPart('24_badge_clear', width: 34, height: 34),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  mission.description,
                  style: const TextStyle(color: wood, fontSize: 12),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final reward = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        uiPart('32_heart_red_1', width: 24, height: 24),
                        const SizedBox(width: 5),
                        const Flexible(
                          child: Text(
                            '社会貢献 +10',
                            style: TextStyle(
                              color: wood,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    );
                    final button = FilledButton(
                      key: ValueKey('complete-${mission.name}'),
                      onPressed: done ? null : onComplete,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC44220),
                        foregroundColor: const Color(0xFFFFF5DB),
                        disabledBackgroundColor: const Color(0xFFE2D7B9),
                        disabledForegroundColor: wood,
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        side: const BorderSide(
                          color: Color(0xFFF5BA57),
                          width: 3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        done ? 'できた！  達成済み' : 'できた！',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: done ? 16 : 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                    if (constraints.maxWidth < 340 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.2) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          reward,
                          const SizedBox(height: 10),
                          SizedBox(width: double.infinity, child: button),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: reward),
                        const SizedBox(width: 8),
                        Expanded(child: button),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
