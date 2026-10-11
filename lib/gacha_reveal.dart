import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_skin.dart';
import 'progress.dart';
import 'resident_collection.dart';

/// Results are already persisted before this route opens.
class GachaReveal extends StatefulWidget {
  const GachaReveal({
    super.key,
    required this.controller,
    required this.resident,
    required this.isNew,
  });
  final ProgressController controller;
  final TownResident resident;
  final bool isNew;
  @override
  State<GachaReveal> createState() => _GachaRevealState();
}

class _GachaRevealState extends State<GachaReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  late TownResident _resident = widget.resident;
  late bool _isNew = widget.isNew;
  bool _drawing = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _play();
    }
    if (MediaQuery.disableAnimationsOf(context)) _animation.value = 1;
  }

  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward(from: 0);
    }
  }

  Future<void> _again() async {
    if (_drawing || !_animation.isCompleted) return;
    setState(() => _drawing = true);
    final before = widget.controller.progress!.residents.counts;
    final resident = await widget.controller.drawResident();
    if (!mounted) return;
    if (resident == null) {
      // Do not cover the main screen's original error and stack trace.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _resident = resident;
      _isNew = !before.containsKey(resident.id);
      _drawing = false;
    });
    _play();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_drawing,
    child: Scaffold(
      backgroundColor: const Color(0xFFFFE8AE),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/kotohogu/town_background_001.jpg',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          Positioned.fill(child: ColoredBox(color: const Color(0xCCFFF4D6))),
          SafeArea(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final t = _animation.value;
                final reveal = Curves.easeOutBack.transform(
                  ((t - .62) / .38).clamp(0.0, 1.0),
                );
                final ready = _animation.isCompleted;
                final progress = widget.controller.progress!;
                final tickets = progress.residents.tickets(progress.points);
                return LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/gacya/gacha_title.png',
                                  width: double.infinity,
                                  height: 112,
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  ready ? 'ようこそ、コトホグへ！' : 'だれに会えるかな…',
                                  style: const TextStyle(
                                    color: wood,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(
                                  height: 330,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _Sparkles(t),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: ((t - .35) / .35).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          child: Transform.scale(
                                            scale: .86 + .14 * t,
                                            child: Image.asset(
                                              'assets/gacya/summon_glow.png',
                                              fit: BoxFit.contain,
                                              excludeFromSemantics: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (var i = 0; i < 3; i++)
                                        Opacity(
                                          opacity: _scrollOpacity(i, t),
                                          child: Image.asset(
                                            'assets/gacya/parts/${['scroll_closed', 'scroll_half', 'scroll_open'][i]}.png',
                                            height: 260,
                                            width: double.infinity,
                                            fit: BoxFit.contain,
                                            excludeFromSemantics: true,
                                          ),
                                        ),
                                      if (t >= .62)
                                        Transform.translate(
                                          offset: Offset(0, 24 * (1 - reveal)),
                                          child: Transform.scale(
                                            scale: reveal,
                                            child: TownResidentAvatar(
                                              resident: _resident,
                                              size: 230,
                                            ),
                                          ),
                                        ),
                                      if (ready)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Image.asset(
                                            'assets/gacya/parts/${_isNew ? 'badge_new' : 'badge_reunion'}.png',
                                            width: 105,
                                            height: 105,
                                            semanticLabel: _isNew
                                                ? 'NEW'
                                                : 'また会えた',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (ready) ...[
                                  Container(
                                    width: 270,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF4D6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFF8E361F),
                                        width: 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0xFFE4B04C),
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: Color(0x663F2313),
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _isNew ? '仲間登場！' : 'また会えた！',
                                          style: const TextStyle(
                                            color: Color(0xFFB83D26),
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          _resident.label,
                                          key: const ValueKey('resident-name'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: wood,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _isNew
                                          ? '${_resident.label}が、まちにやってきました！'
                                          : '${_resident.label}とまた出会いました！',
                                      key: const ValueKey('gacha-result'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: wood,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '累計${progress.residents.counts[_resident.id]}回 ・ ガチャ券 $tickets枚',
                                    style: const TextStyle(color: wood),
                                  ),
                                  const SizedBox(height: 20),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _ArtButton(
                                        name: 'button_town',
                                        label: 'まちへ',
                                        onPressed: _drawing
                                            ? null
                                            : () =>
                                                  Navigator.of(context)
                                                      .pop(true),
                                      ),
                                      _ArtButton(
                                        name: 'button_again',
                                        label: 'もう1回（券1枚）',
                                        onPressed: _drawing || tickets == 0
                                            ? null
                                            : _again,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _drawing
                                        ? '住民を迎えています…'
                                        : tickets == 0
                                        ? '次の券は、日々の行動で。また会いにきてね。'
                                        : 'もう1回はガチャ券を1枚使います。',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: wood),
                                  ),
                                ] else
                                  const SizedBox(height: 160),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  double _scrollOpacity(int index, double t) {
    final first = ((t - .12) / .22).clamp(0.0, 1.0);
    final second = ((t - .34) / .25).clamp(0.0, 1.0);
    return switch (index) {
      0 => 1 - first,
      1 => first * (1 - second),
      _ => second,
    };
  }
}

class _ArtButton extends StatelessWidget {
  const _ArtButton({required this.name, required this.label, this.onPressed});
  final String name, label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    enabled: onPressed != null,
    child: Tooltip(
      message: label,
      child: TextButton(
        key: ValueKey(name),
        onPressed: onPressed,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Opacity(
          opacity: onPressed == null ? .45 : 1,
          child: Image.asset(
            'assets/gacya/parts/$name.png',
            width: 170,
            height: 85,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    ),
  );
}

class _Sparkles extends CustomPainter {
  _Sparkles(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final strength = ((t - .35) / .3).clamp(0.0, 1.0);
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: strength),
          const Color(0xFFFFD563).withValues(alpha: strength * .6),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawOval(Offset.zero & size, paint);
    for (var i = 0; i < 18; i++) {
      final angle = i * math.pi * 2 / 18;
      final radius = 95 + 55 * strength + 10 * math.sin(t * math.pi * 4 + i);
      final p =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      final r = (i.isEven ? 10.0 : 6.0) * strength;
      final path = Path()
        ..moveTo(p.dx, p.dy - r)
        ..lineTo(p.dx + r * .4, p.dy)
        ..lineTo(p.dx, p.dy + r)
        ..lineTo(p.dx - r * .4, p.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = i.isEven ? const Color(0xFFFFBE36) : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_Sparkles oldDelegate) => oldDelegate.t != t;
}
