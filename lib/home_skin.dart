import 'package:flutter/material.dart';

import 'progress.dart';

const wood = Color(0xFF63351F);
const gold = Color(0xFFE6AF53);

Widget uiPart(String name, {double? width, double? height}) => Image.asset(
  'assets/kotohogu/$name.png',
  width: width,
  height: height,
  fit: BoxFit.contain,
  excludeFromSemantics: true,
);

BoxDecoration parchment({bool completed = false}) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: completed
        ? const [Color(0xFFFFF8E6), Color(0xFFF3E8CC)]
        : const [Color(0xFFFFFBEB), Color(0xFFFFEDC2)],
  ),
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: gold, width: 2),
  boxShadow: const [
    BoxShadow(color: Color(0xFF986137), offset: Offset(0, 3)),
    BoxShadow(color: Color(0x18744520), offset: Offset(0, 6), blurRadius: 10),
  ],
);

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/kotohogu/31_dialogue_box.png',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth * .17,
            57,
            constraints.maxWidth * .11,
            36,
          ),
          child: Semantics(
            label: 'ハルからのメッセージ',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日の小さな行動が、\n誰かの未来につながる。',
                  style: TextStyle(
                    color: wood,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'あなたのペースで。\nできたことを、ひとつずつ。',
                  style: TextStyle(
                    color: Color(0xFF82583B),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shrine-style HUD showing the live earned kotohogi amount.
class KotohogiBar extends StatelessWidget {
  const KotohogiBar({super.key, required this.points});

  /// The underlying persistent points field is intentionally unchanged.
  final int points;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      // A layout transition may briefly measure the HUD at zero width.
      // The parent supplies a fixed positive width in normal layouts; do
      // not crash the entire screen during a transient zero-size pass.
      if (!width.isFinite || width <= 0) {
        return const SizedBox.shrink();
      }
      final height = width * 211 / 982;
      return Semantics(
        label: 'ことほぎ $points',
        liveRegion: true,
        child: ExcludeSemantics(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/kotohogi_hud/kotohogi_bar.png',
                    key: const ValueKey('kotohogi-bar-art'),
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                  ),
                ),
                // The replacement asset has a plain red space on the right.
                // Draw the actual, persisted balance there, without a circle.
                // Allocate enough width for 4-6 digits on compact phones.
                Positioned(
                  left: width * .63,
                  right: width * .055,
                  top: height * .12,
                  bottom: height * .12,
                  child: SizedBox(
                    key: const ValueKey('kotohogi-number-zone'),
                    child: FittedBox(
                      alignment: Alignment.centerRight,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$points',
                        key: const ValueKey('total-points'),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          color: Color(0xFFFFF4D6),
                          shadows: [
                            Shadow(
                              color: Color(0xFF3B100B),
                              blurRadius: 2,
                              offset: Offset(1, 2),
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
    },
  );
}

class ContributionPanel extends StatelessWidget {
  const ContributionPanel({super.key, required this.points});
  final int points;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: KotohogiBar(points: points),
    ),
  );
}

class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
    required this.done,
    required this.onComplete,
  });
  final Mission mission;
  final bool done;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final icon = switch (mission) {
      Mission.strength => Icons.accessibility_new_rounded,
      Mission.outside => Icons.directions_walk_rounded,
      Mission.conversation => Icons.forum_rounded,
      _ => Icons.favorite_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: parchment(completed: done),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFDF8E),
                  border: Border.all(color: gold, width: 2),
                ),
                child: Icon(icon, color: wood, size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mission.title,
                  style: const TextStyle(
                    color: wood,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (done)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: uiPart('24_badge_clear', width: 42, height: 42),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            mission.description,
            style: const TextStyle(color: Color(0xFF82583B), fontSize: 13),
          ),
          const SizedBox(height: 15),
          // Text stays native Flutter text: it scales and announces the real state.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF8D4424), width: 2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: done
                    ? const [Color(0xFFEEE3C4), Color(0xFFDCCC9F)]
                    : const [
                        Color(0xFFFF8F46),
                        Color(0xFFE94B20),
                        Color(0xFFBA341C),
                      ],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0xFFAE6B32), offset: Offset(0, 3)),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: ValueKey('complete-${mission.name}'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: const Color(0xFFFFF5DB),
                  disabledForegroundColor: wood,
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  side: const BorderSide(color: Color(0xFFFFD36D), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(21),
                  ),
                ),
                onPressed: done ? null : onComplete,
                child: Text(
                  done ? 'できた！  達成済み' : 'できた！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: done ? 18 : 25,
                    fontWeight: FontWeight.w900,
                    shadows: done
                        ? null
                        : const [
                            Shadow(
                              color: Color(0xFF96351D),
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
