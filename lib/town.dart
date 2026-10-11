import 'package:flutter/material.dart';

import 'resident_collection.dart';

const townNames = ['穏やかなまち', '花のあるまち', '笑顔が集まるまち', 'にぎやかなまち'];
const townDescriptions = [
  'いつものまちで、みんなが暮らしています。',
  '道ばたに、色とりどりの花が咲きました。',
  '公園に、笑顔の住民が集まってきました。',
  '小さな飾りが、まちの日常を彩っています。',
];

class TownScene extends StatelessWidget {
  const TownScene({
    super.key,
    required this.level,
    required this.residents,
    this.onResident,
  });
  final int level;
  final List<TownResident> residents;
  final ValueChanged<TownResident>? onResident;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.22,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          const slots = [
            (.10, .51),
            (.63, .49),
            (.33, .65),
            (.72, .73),
            (.03, .76),
            (.48, .47),
            (.28, .43),
            (.50, .76),
          ];
          final people = [
            for (var i = 0; i < residents.length && i < townResidentLimit; i++)
              (residents[i], slots[i].$1, slots[i].$2),
          ];
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/kotohogu/town_background_001.jpg',
                  key: const ValueKey('town-background'),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              for (var index = 0; index < people.length; index++)
                Positioned(
                  left: width * people[index].$2,
                  top: height * people[index].$3,
                  child: Semantics(
                    button: onResident != null,
                    label: '${people[index].$1.label}のTips',
                    child: Tooltip(
                      message: people[index].$1.label,
                      child: InkWell(
                        key: ValueKey('resident-$index'),
                        borderRadius: BorderRadius.circular(20),
                        onTap: onResident == null
                            ? null
                            : () => onResident!(people[index].$1),
                        child: TownResidentAvatar(
                          resident: people[index].$1,
                          size: (width * .14).clamp(40.0, 76.0),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
