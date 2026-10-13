import 'package:flutter/material.dart';

import 'consultation_scene.dart';
import 'home_skin.dart';
import 'progress.dart';
import 'resident_collection.dart';

/// The result was durably saved before navigating here. The animation is
/// cosmetic: a resident appears on the blue stage with a glow behind it.
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
    final progress = widget.controller.progress!;
    if (widget.controller.busy ||
        progress.residents.tickets(progress.points) <= 0) {
      return;
    }
    setState(() => _drawing = true);
    final before = Map<String, int>.of(progress.residents.counts);
    final resident = await widget.controller.drawResident();
    if (!mounted) return;
    if (resident == null) {
      // The caller retains the original exception and its stack trace.
      Navigator.of(context).pop(false);
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
      backgroundColor: const Color(0xFFFBE9C8),
      body: Stack(
        children: [
          const Positioned.fill(child: ConsultationBackground()),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final t = _animation.value;
                final ready = _animation.isCompleted;
                final entry = Curves.easeOutBack.transform(
                  ((t - .30) / .42).clamp(0.0, 1.0),
                );
                final visible = ((t - .24) / .26).clamp(0.0, 1.0);
                final progress = widget.controller.progress!;
                final balance =
                    progress.residents.availableKotohogi(progress.points);
                final canRepeat = ready &&
                    !_drawing &&
                    !widget.controller.busy &&
                    progress.residents.tickets(progress.points) > 0;
                final safe = MediaQuery.paddingOf(context);

                return Stack(
                  children: [
                    Positioned(
                      top: safe.top + 10,
                      left: 12,
                      width: (width * .54).clamp(170.0, 300.0),
                      child: KotohogiBar(points: balance),
                    ),
                    Positioned(
                      top: safe.top + 12,
                      right: 12,
                      child: IconButton(
                        key: const ValueKey('gacha-back-town'),
                        tooltip: 'まちへ戻る',
                        onPressed: _drawing
                            ? null
                            : () => Navigator.of(context).pop(true),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF63351F),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xEEFFF1D4),
                        ),
                      ),
                    ),
                    // All arrival art shares the background's 1080x1920
                    // coordinate system, including BoxFit.cover cropping.
                    Positioned.fill(
                      child: ConsultationComposition.cover(
                        Stack(
                          children: [
                            if (t >= .20)
                              Positioned.fromRect(
                                rect: ConsultationComposition.glow,
                                child: Opacity(
                                  opacity: visible,
                                  child: Transform.scale(
                                    scale: 1 + .12 * t,
                                    child: Image.asset(
                                      'assets/gacya/summon_glow.png',
                                      key: const ValueKey('gacha-reveal-glow'),
                                      fit: BoxFit.contain,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ),
                            if (t >= .30)
                              Positioned.fromRect(
                                rect: ConsultationComposition.resident,
                                child: Opacity(
                                  opacity: visible,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - entry) * 55),
                                    child: Transform.scale(
                                      scale: entry,
                                      child: Image.asset(
                                        _resident.idleAsset,
                                        key: const ValueKey(
                                          'gacha-stage-resident',
                                        ),
                                        fit: BoxFit.contain,
                                        excludeFromSemantics: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (t >= .67) ...[
                              Positioned.fromRect(
                                rect: ConsultationComposition.banner,
                                child: Semantics(
                                  key: const ValueKey('gacha-result'),
                                  liveRegion: true,
                                  label: _isNew
                                      ? '${_resident.label}が、まちにやってきました！'
                                      : '${_resident.label}とまた出会いました！',
                                  child: LayoutBuilder(
                                    builder: (context, bannerSize) {
                                      final bw = bannerSize.maxWidth;
                                      final bh = bannerSize.maxHeight;
                                      return Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Image.asset(
                                              'assets/gacya/resident_arrival_banner.png',
                                              key: const ValueKey(
                                                'resident-arrival-banner',
                                              ),
                                              fit: BoxFit.contain,
                                              excludeFromSemantics: true,
                                            ),
                                          ),
                                          Positioned(
                                            left: bw * .17,
                                            top: bh * .555,
                                            width: bw * .41,
                                            height: bh * .16,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _resident.label,
                                                key: const ValueKey(
                                                  'gacha-banner-resident-name',
                                                ),
                                                maxLines: 1,
                                                style: const TextStyle(
                                                  fontSize: 60,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF532812),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                              if (!_isNew)
                                Positioned(
                                  left: ConsultationComposition.banner.left - 30,
                                  top: ConsultationComposition.banner.top - 35,
                                  width: 190,
                                  height: 190,
                                  child: Image.asset(
                                    'assets/gacya/parts/badge_reunion.png',
                                    key: const ValueKey('gacha-reunion-badge'),
                                    fit: BoxFit.contain,
                                    semanticLabel: 'また会えた',
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: safe.bottom + 14,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ready)
                            Text(
                              _drawing
                                  ? '住民をお迎えしています…'
                                  : canRepeat
                                      ? '開催費：30ことほぎ'
                                      : 'ことほぎが足りません',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF542C1B),
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFFFF4E1),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ConsultationActions(
                            onResidents: () => showResidentCollection(
                              context,
                              progress.residents,
                            ),
                            onAgain: canRepeat ? _again : null,
                            againLabel: 'もう一度開く（30ことほぎ）',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
