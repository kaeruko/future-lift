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
    required this.period,
    required this.onPeriodChanged,
  });
  final Progress progress;
  final bool busy;
  final ValueChanged<Mission> onComplete;
  final MissionPeriod period;
  final ValueChanged<MissionPeriod> onPeriodChanged;

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
                      child: Text(
                        switch (period) {
                          MissionPeriod.daily => '今日できたことを、教えてね。',
                          MissionPeriod.weekly => '今週できたことを、教えてね。',
                          MissionPeriod.monthly => '今月できたことを、教えてね。',
                        },
                        style: const TextStyle(
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xEEFFF5DF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${progress.completedFor(period).length}/${Mission.forPeriod(period).length} 言祝ぎ',
              key: const ValueKey('mission-period-progress'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: wood, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          _MissionTabs(period: period, onChanged: onPeriodChanged),
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
                      for (final mission in Mission.forPeriod(period))
                        _QuestCard(
                          mission: mission,
                          done: progress.completedFor(period).contains(mission),
                          onComplete: busy ? null : () => onComplete(mission),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          switch (period) {
                            MissionPeriod.daily =>
                              '量や回数は問いません。\n今日行動したことを、みんなで祝います。',
                            MissionPeriod.weekly =>
                              '今週できたことだけを言祝ぎます。\nできなかったことは気にしなくて大丈夫。',
                            MissionPeriod.monthly =>
                              '今月できたことを振り返りましょう。\n未達成のミッションに罰はありません。',
                          },
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

/// Reuse the provided gold and wood frames; render live labels above their
/// baked-in lettering so every period has both selected and unselected states.
class _MissionTabs extends StatelessWidget {
  const _MissionTabs({required this.period, required this.onChanged});
  final MissionPeriod period;
  final ValueChanged<MissionPeriod> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final tabWidth = (constraints.maxWidth / 3).clamp(
        116 * scale,
        double.infinity,
      );
      return Padding(
        padding: EdgeInsets.zero,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (final candidate in MissionPeriod.values)
              SizedBox(
                width: tabWidth,
                height: 60 * scale,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    2,
                    candidate == period ? 0 : 7,
                    2,
                    0,
                  ),
                  child: _MissionTab(
                    key: ValueKey('mission-tab-${candidate.name}'),
                    selected: candidate == period,
                    label: switch (candidate) {
                      MissionPeriod.daily => 'デイリー',
                      MissionPeriod.weekly => 'ウィークリー',
                      MissionPeriod.monthly => 'マンスリー',
                    },
                    onTap: () => onChanged(candidate),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _MissionTab extends StatelessWidget {
  const _MissionTab({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/quests/tab_${selected ? 'selected' : 'unselected'}.png',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
            Positioned.fill(
              left: 12,
              right: 12,
              top: 12,
              bottom: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: selected
                        ? const [Color(0xFFFFE5A0), Color(0xFFF6C96B)]
                        : const [Color(0xFFB57A38), Color(0xFF93531F)],
                  ),
                ),
                child: Center(
                  child: ExcludeSemantics(
                    child: Stack(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 4
                              ..color = wood,
                          ),
                        ),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFF4D6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
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
                        _ => Icons.favorite_rounded,
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
