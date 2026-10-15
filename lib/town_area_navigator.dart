import 'package:flutter/material.dart';

import 'resident_collection.dart';
import 'town.dart';
import 'town_areas.dart';

/// Swipe or use arrows to move between independent town neighborhoods.
class TownAreaNavigator extends StatefulWidget {
  const TownAreaNavigator({
    super.key,
    required this.area,
    required this.onAreaChanged,
    required this.level,
    required this.lifetimePoints,
    required this.residents,
    this.debugTownResidents,
    this.onResident,
  });

  final TownArea area;
  final ValueChanged<TownArea> onAreaChanged;
  final int level;
  final int lifetimePoints;
  final List<TownResident> residents;
  final List<TownResident>? debugTownResidents;
  final Future<void> Function(TownResident)? onResident;

  @override
  State<TownAreaNavigator> createState() => _TownAreaNavigatorState();
}

class _TownAreaNavigatorState extends State<TownAreaNavigator> {
  double _dragDistance = 0;

  void _move(int direction) {
    final next = widget.area.index + direction;
    if (next < 0 || next >= TownArea.values.length) return;
    widget.onAreaChanged(TownArea.values[next]);
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    final debugPreview = widget.debugTownResidents != null;
    final unlocked = area.isUnlocked(widget.lifetimePoints);
    final accessible = unlocked || debugPreview;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (event) => _dragDistance += event.primaryDelta ?? 0,
      onHorizontalDragEnd: (_) {
        if (_dragDistance <= -45) _move(1);
        if (_dragDistance >= 45) _move(-1);
        _dragDistance = 0;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (accessible && area.backgroundAsset != null)
            TownScene(
              level: widget.level,
              area: area,
              residents: widget.residents,
              debugTownResidents: widget.debugTownResidents,
              onResident: widget.onResident,
              fillViewport: true,
            )
          else
            _AreaPreparation(
              area: area,
              unlocked: unlocked,
              debugPreview: debugPreview,
              lifetimePoints: widget.lifetimePoints,
              residents: areaResidents(
                widget.residents,
                area,
                debugOverride: widget.debugTownResidents,
              ),
              onResident: widget.onResident,
            ),
          Positioned(
            top: 92,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('town-area-previous'),
                  tooltip: '前のエリア',
                  onPressed: area.index == 0 ? null : () => _move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xEEFFF5DB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          area.label,
                          key: const ValueKey('town-area-name'),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF63351F),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${area.index + 1} / ${TownArea.values.length}',
                          style: const TextStyle(
                            color: Color(0xFF87664A), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('town-area-next'),
                  tooltip: '次のエリア',
                  onPressed: area.index == TownArea.values.length - 1
                      ? null : () => _move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                key: const ValueKey('town-page-title-panel'),
                decoration: BoxDecoration(
                  color: const Color(0xEEFFF6DC),
                  border: Border.all(color: const Color(0xFFD4A64E), width: 2),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (area == TownArea.plaza) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF277A70),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'LEVEL ${widget.level}',
                          style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        area == TownArea.plaza
                            ? townNames[widget.level] : area.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          color: Color(0xFF63351F),
                          fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Unfinished background art stays explicit; residents can still chat in
/// unlocked areas, while a locked area reveals neither its roster nor chats.
class _AreaPreparation extends StatelessWidget {
  const _AreaPreparation({
    required this.area,
    required this.unlocked,
    required this.debugPreview,
    required this.lifetimePoints,
    required this.residents,
    required this.onResident,
  });

  final TownArea area;
  final bool unlocked;
  final bool debugPreview;
  final int lifetimePoints;
  final List<TownResident> residents;
  final Future<void> Function(TownResident)? onResident;

  @override
  Widget build(BuildContext context) {
    final accessible = unlocked || debugPreview;
    return ColoredBox(
      color: const Color(0xFFFFF1DE),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 172, 24, 84),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                accessible ? Icons.home_work_outlined : Icons.lock_outline,
                size: 56, color: const Color(0xFF906B55)),
              const SizedBox(height: 14),
              Text(
                accessible ? '景色を準備中だよ' : 'まだ行けないエリアだよ',
                key: const ValueKey('town-area-status'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF63351F),
                  fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                accessible ? area.description
                    : '累計${area.unlockAt}ことほぎで開放\n'
                      'あと${area.unlockAt - lifetimePoints}ことほぎ',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6E5B4A), height: 1.7),
              ),
              if (debugPreview && !unlocked) ...[
                const SizedBox(height: 6),
                const Text('デバッグ用プレビュー',
                    style: TextStyle(fontSize: 12)),
              ],
              if (accessible) ...[
                const SizedBox(height: 22),
                if (residents.isEmpty)
                  const Text('住民が引っ越してくるのを待っているよ。')
                else ...[
                  const Text('このエリアの住民',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final resident in residents)
                        Semantics(
                          button: onResident != null,
                          label: '${resident.label}のおはなし',
                          child: InkWell(
                            key: ValueKey('area-resident-${resident.id}'),
                            onTap: onResident == null ? null
                                : () => onResident!(resident),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 88,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9EA),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE7CBA0)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    resident.idleAsset,
                                    width: 58, height: 58,
                                    excludeFromSemantics: true),
                                  Text(
                                    resident.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
