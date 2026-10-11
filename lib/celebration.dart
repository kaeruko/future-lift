import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'clap_characters.dart';

class Celebration extends StatefulWidget {
  const Celebration({
    super.key,
    required this.missionTitle,
    required this.total,
  });
  final String missionTitle;
  final int total;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with TickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
  );
  late final _applause = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced == reduced) return;
    _reduced = reduced;
    if (reduced) {
      _entrance.value = 1;
      _confetti.stop();
      _applause.stop();
    } else {
      _entrance.forward();
      _confetti.forward(from: 0);
      _applause.repeat();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _confetti.dispose();
    _applause.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF244C62), Color(0xFF353660), Color(0xFF654D79)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, child) => CustomPaint(
                  painter: _ConfettiPainter(_reduced! ? .23 : _confetti.value),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'まちのみんなから、あなたへ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFE1DEEF),
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFFFDE86),
                        size: 52,
                      ),
                      const SizedBox(height: 14),
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(
                            0,
                            .7,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'ありがとう！',
                              style: TextStyle(
                                fontSize: 50,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFE4A0),
                                shadows: [
                                  Shadow(
                                    color: Color(0x55000000),
                                    offset: Offset(0, 4),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '未来の社会を\nちょっと助けました',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.6,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      AnimatedBuilder(
                        animation: _applause,
                        builder: (context, child) => ClapCharacters(
                          phase: _applause.value,
                          reduced: _reduced!,
                        ),
                      ),
                      const SizedBox(height: 25),
                      SlideTransition(
                        position:
                            Tween(
                              begin: const Offset(0, .3),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _entrance,
                                curve: const Interval(
                                  .25,
                                  1,
                                  curve: Curves.easeOutBack,
                                ),
                              ),
                            ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE19A),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33FFCB65),
                                blurRadius: 32,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '社会貢献 +10',
                                style: TextStyle(
                                  fontSize: 32,
                                  color: Color(0xFF533E33),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'これまでの社会貢献  ${widget.total} pt',
                                style: const TextStyle(
                                  color: Color(0xFF695344),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        '「${widget.missionTitle}」\n今日の行動が、まちに届きました。',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE1DEEF),
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('close-celebration'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF393B61),
                            minimumSize: const Size(0, 60),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'ありがとうを受け取る',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.time);
  final double time;
  static const colors = [
    Color(0xFFFFDC7E),
    Color(0xFFFF99B0),
    Color(0xFF8DD9D2),
    Color(0xFFBAA7EE),
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(31);
    final paint = Paint()..isAntiAlias = true;
    for (var i = 0; i < 110; i++) {
      final startX = random.nextDouble();
      final delay = random.nextDouble() * .38;
      final speed = .7 + random.nextDouble() * .65;
      final drift = random.nextDouble() * 2 - 1;
      final t = time - delay;
      if (t < 0) continue;
      final x = startX * size.width + math.sin(t * 8 + i) * 30 + drift * t * 50;
      final y = -30 + t * speed * (size.height + 180);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(i + t * drift * 12);
      paint.color = colors[i % colors.length];
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, 3.5, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: 5 + 4 * math.sin(t * 14 + i).abs(),
            height: 13,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.time != time;
}
