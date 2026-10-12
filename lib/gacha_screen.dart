import 'package:flutter/material.dart';

import 'gacha_hud.dart';
import 'gacha_reveal.dart';
import 'progress.dart';
import 'resident_collection.dart';
import 'ticket_counter_badge.dart';

/// The shrine is a separate, scroll-safe screen instead of an inline town card.
/// One draw retains the familiar animated reveal, while a bundle lists all 11.
class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key, required this.controller});
  final ProgressController controller;

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen> {
  bool _drawing = false;

  Future<void> _draw({required bool bundle}) async {
    final progress = widget.controller.progress;
    final cost = bundle ? 10 : 1;
    if (_drawing || widget.controller.busy ||
        progress == null ||
        progress.residents.tickets(progress.points) < cost) {
      return;
    }
    setState(() => _drawing = true);
    final before = Map<String, int>.of(progress.residents.counts);
    try {
      if (bundle) {
        final results = await widget.controller.drawResidentsTenPlusOne();
        if (!mounted || results == null) return;
        final firstAppearance = <bool>[];
        for (final resident in results) {
          firstAppearance.add(!before.containsKey(resident.id));
          before[resident.id] = (before[resident.id] ?? 0) + 1;
        }
        final town = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => GachaBundleReveal(
              controller: widget.controller,
              residents: results,
              firstAppearance: firstAppearance,
            ),
          ),
        );
        if (mounted && town == true) Navigator.of(context).pop(true);
      } else {
        final result = await widget.controller.drawResident();
        if (!mounted || result == null) return;
        final town = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => GachaReveal(
              controller: widget.controller,
              resident: result,
              isNew: !before.containsKey(result.id),
            ),
          ),
        );
        if (mounted && town == true) Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        if (widget.controller.failure != null) {
          // The outer home owns the full diagnostic screen.
          Navigator.of(context).pop(false);
        } else {
          setState(() => _drawing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final progress = widget.controller.progress!;
      final tickets = progress.residents.tickets(progress.points);
      return Scaffold(
        backgroundColor: const Color(0xFFFBE9C8),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/gacya/bg.png',
                key: const ValueKey('gacha-shrine-bg'),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 570),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
                          child: Column(
                            children: [
                              GachaHud(points: progress.points),
                              const SizedBox(height: 18),
                              Image.asset(
                                'assets/gacya/gacha_title.png',
                                width: double.infinity,
                                height: 140,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                              ),
                              const SizedBox(height: 10),
                              _ticketLabel(tickets),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 345,
                                child: LayoutBuilder(
                                  builder: (context, c) {
                                    final buttonWidth = (c.maxWidth * .32)
                                        .clamp(90.0, 156.0);
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        Positioned(
                                          top: 2,
                                          bottom: 0,
                                          left: c.maxWidth * .18,
                                          right: c.maxWidth * .18,
                                          child: Image.asset(
                                            'assets/gacya/scroll_display_stand.png',
                                            key: const ValueKey('gacha-scroll-stand'),
                                            fit: BoxFit.contain,
                                            excludeFromSemantics: true,
                                          ),
                                        ),
                                        Positioned(
                                          left: 0,
                                          bottom: 52,
                                          width: buttonWidth,
                                          child: _button(
                                            asset: 'assets/gacya/button.png',
                                            keyName: 'gacha-draw-one',
                                            label: '1回引く（ガチャ券1枚）',
                                            enabled: !_drawing && !widget.controller.busy && tickets >= 1,
                                            onTap: () => _draw(bundle: false),
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 52,
                                          width: buttonWidth,
                                          child: _button(
                                            asset: 'assets/gacya/button10.png',
                                            keyName: 'gacha-draw-ten',
                                            label: '10回引く（券10枚で11回抽選）',
                                            enabled: !_drawing && !widget.controller.busy && tickets >= 10,
                                            onTap: () => _draw(bundle: true),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xE8FFF4D8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                                child: Text(
                                  _drawing
                                      ? '仲間を迎えています…'
                                      : '1回：券1枚 ／ 10回：券10枚で11回（1回無料）',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF653B27),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                key: const ValueKey('gacha-back-town'),
                                onPressed: _drawing ? null :
                                    () => Navigator.of(context).pop(false),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('みんなのまちへ戻る'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _ticketLabel(int tickets) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xE9FFF0C9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFC78B36), width: 2),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('所持ガチャ券',
                maxLines: 1,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ),
          ),
          TicketCounterBadge(
            key: const ValueKey('gacha-screen-tickets'),
            tickets: tickets,
          ),
        ],
      ),
    ),
  );

  Widget _button({
    required String asset,
    required String keyName,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    enabled: enabled,
    label: label,
    child: Tooltip(
      message: label,
      child: TextButton(
        key: ValueKey(keyName),
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(64, 64),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Opacity(
          opacity: enabled ? 1 : .5,
          child: Image.asset(
            asset,
            height: 82,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    ),
  );
}

/// Ten-ticket bundle: all eleven results are visible and persisted at once.
class GachaBundleReveal extends StatelessWidget {
  const GachaBundleReveal({
    super.key,
    required this.controller,
    required this.residents,
    required this.firstAppearance,
  }) : assert(residents.length == 11),
       assert(firstAppearance.length == 11);

  final ProgressController controller;
  final List<TownResident> residents;
  final List<bool> firstAppearance;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFE8AE),
    body: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/gacya/bg.png',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  children: [
                    GachaHud(points: controller.progress!.points),
                    const SizedBox(height: 12),
                    Image.asset(
                      'assets/gacya/gacha_title.png',
                      height: 108,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xEEFFF1D4),
                        border: Border.all(
                          color: const Color(0xFFC78B36),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('11人との出会い！',
                            key: ValueKey('gacha-bundle-title'),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              color: Color(0xFF67371F),
                            )),
                          const Text('10回分の券で、1回おまけ',
                            style: TextStyle(color: Color(0xFF67371F))),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 14,
                            children: [
                              for (var i = 0; i < residents.length; i++)
                                SizedBox(
                                  key: ValueKey('gacha-result-$i'),
                                  width: 88,
                                  child: Column(
                                    children: [
                                      TownResidentAvatar(
                                        resident: residents[i], size: 75,
                                      ),
                                      Text(
                                        residents[i].label,
                                        style: const TextStyle(fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                      ),
                                      Text(firstAppearance[i] ? 'NEW!' : 'また会えた',
                                        style: const TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TicketCounterBadge(
                      key: const ValueKey('gacha-bundle-tickets'),
                      tickets: controller.progress!.residents.tickets(
                        controller.progress!.points),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const ValueKey('gacha-bundle-town'),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('まちへ'),
                    ),
                    TextButton(
                      key: const ValueKey('gacha-bundle-again'),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('ガチャ画面へ戻る'),
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
