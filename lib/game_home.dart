import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_skin.dart';
import 'progress.dart';
import 'residents.dart';

/// The town lobby links to the daily mission board.
class GameHome extends StatefulWidget {
  const GameHome({
    super.key,
    required this.progress,
    required this.onMissions,
    required this.onTown,
    required this.onResident,
  });
  final Progress progress;
  final VoidCallback onMissions;

  final VoidCallback onTown;
  final ValueChanged<Resident> onResident;

  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.max(constraints.maxHeight, 620.0);
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final sceneHeight = height + math.max(0, scale - 1) * 300;
      return ListView(
        controller: _scroll,
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: sceneHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/kotohogu/town_background.png',
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF70391E), Color(0xFF9B482B)],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFD383),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x80522113),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        uiPart('32_heart_red_1', width: 34, height: 34),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '社会貢献ポイント',
                            style: TextStyle(
                              color: Color(0xFFFFE8B5),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.progress.points}',
                          key: const ValueKey('total-points'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                        const Text(
                          ' pt',
                          style: TextStyle(color: Color(0xFFFFE8B5)),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: sceneHeight * .16,
                  left: 24,
                  right: 24,
                  child: Column(
                    children: [
                      Semantics(
                        header: true,
                        label: 'FutureLift',
                        child: ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Stack(
                              children: [
                                Text(
                                  'FutureLift',
                                  style: TextStyle(
                                    fontSize: 61,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 10
                                      ..color = const Color(0xFFFFF6D6),
                                  ),
                                ),
                                const Text(
                                  'FutureLift',
                                  style: TextStyle(
                                    fontSize: 61,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                    color: wood,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFBD3D20),
                              Color(0xFFE6672B),
                              Color(0xFFBD3D20),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFFFFD681),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: wood, offset: Offset(0, 3)),
                          ],
                        ),
                        child: const Text(
                          'みんなのまち',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: sceneHeight * .43,
                  left: 22,
                  right: 22,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xF5FFF5DA),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: gold, width: 2),
                        ),
                        child: const Text(
                          '今日の小さな行動を、みんなで祝おう。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: wood,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth * .10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final resident in Resident.values)
                              Flexible(
                                child: Semantics(
                                  button: true,
                                  label: '${resident.label}のTips',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: () => widget.onResident(resident),
                                    child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: ResidentAvatar(
                                        resident: resident,
                                        size: (constraints.maxWidth * .15)
                                            .clamp(44, 80),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 18,
                  left: 14,
                  right: 14,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: math.min(
                              (constraints.maxWidth - 58) / 2,
                              175,
                            ),
                            child: _LobbySign(
                              key: const ValueKey('open-missions'),
                              asset: '10_nav_quest',
                              title: '本日のミッション',
                              detail:
                                  '${widget.progress.completed.length} / ${Mission.forPeriod(MissionPeriod.daily).length} 達成',
                              onTap: widget.onMissions,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: math.min(
                              (constraints.maxWidth - 58) / 2,
                              175,
                            ),
                            child: _LobbySign(
                              asset: '11_nav_town',
                              title: 'みんなのまちへ',
                              detail: 'LEVEL ${widget.progress.townLevel}',
                              onTap: widget.onTown,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xF5FFF4DA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'あなたのペースで、できたことをひとつずつ。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: wood,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
      );
    },
  );
}

class _LobbySign extends StatelessWidget {
  const _LobbySign({
    super.key,
    required this.asset,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final String asset;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Ink(
          decoration: parchment(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              uiPart(asset, height: 52),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: wood,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: wood,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFE6AD),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
