import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Supplied three-frame sprites. Keep every frame mounted to avoid flicker.
class ClapCharacters extends StatelessWidget {
  const ClapCharacters({super.key, required this.phase, required this.reduced});

  final double phase;
  final bool reduced;
  static const characters = [
    ('01_shiba', 'しばいぬ'),
    ('02_rabbit', 'うさぎ'),
    ('03_penguin', 'ペンギン'),
    ('04_chef_cat', 'シェフのねこ'),
    ('05_squirrel', 'りす'),
    ('06_grandma_sheep', 'ひつじのおばあちゃん'),
    ('07_business_frog', 'ビジネスマンのかえる'),
    ('08_mail_bird', 'ゆうびんやさん'),
  ];
  static const frames = ['01_hands_apart', '02_clap', '03_hands_apart'];

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var row = 0; row < 2; row++)
        Row(
          children: [
            for (var col = 0; col < 4; col++)
              Expanded(child: _character(row * 4 + col)),
          ],
        ),
    ],
  );

  Widget _character(int index) {
    final (id, name) = characters[index];
    final time = (phase + index * .07) % 1;
    final frame = reduced ? 1 : [0, 1, 2, 1][(time * 4).floor()];
    return Semantics(
      label: '$nameが拍手しています',
      image: true,
      child: Transform.translate(
        offset: Offset(0, reduced ? 0 : -8 * math.sin(time * math.pi).abs()),
        child: AspectRatio(
          aspectRatio: 1,
          child: IndexedStack(
            key: ValueKey('clap-$id'),
            index: frame,
            sizing: StackFit.expand,
            children: [
              for (final frameName in frames)
                Image.asset(
                  'assets/clap/${id}_$frameName.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
