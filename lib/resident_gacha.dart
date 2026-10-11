import 'package:flutter/material.dart';

import 'progress.dart';
import 'resident_collection.dart';
import 'home_skin.dart';

/// Inline panel keeps save failures visible on the main diagnostic screen.
class ResidentGacha extends StatefulWidget {
  const ResidentGacha({super.key, required this.controller});
  final ProgressController controller;
  @override
  State<ResidentGacha> createState() => _ResidentGachaState();
}

class _ResidentGachaState extends State<ResidentGacha> {
  TownResident? _result;
  bool _newResident = false;

  Future<void> _draw() async {
    final before = widget.controller.progress!.residents.counts;
    final result = await widget.controller.drawResident();
    if (!mounted || result == null) return;
    setState(() {
      _result = result;
      _newResident = !before.containsKey(result.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.controller.progress!;
    final collection = progress.residents;
    final tickets = collection.tickets(progress.points);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: parchment(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'まちの仲間 ${collection.owned.length}/$ownedResidentLimit人',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('住民ガチャ券 $tickets枚', key: const ValueKey('resident-tickets')),
          Text(
            'あと${collection.untilNextTicket(progress.points)}ポイントで券を1枚もらえます。',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('draw-resident'),
            onPressed: widget.controller.busy || tickets == 0 ? null : _draw,
            icon: const Icon(Icons.celebration_outlined),
            label: Text(widget.controller.busy ? '住民を迎えています…' : '住民を迎える（券1枚）'),
          ),
          const SizedBox(height: 8),
          const Text(
            '全6種類が同じ確率（各1/6）で登場します。\n同じ住民と再会することもあります。',
            style: TextStyle(fontSize: 12),
          ),
          if (_result case final resident?) ...[
            const Divider(height: 28),
            Center(child: TownResidentAvatar(resident: resident, size: 110)),
            Semantics(
              liveRegion: true,
              child: Text(
                _newResident
                    ? '${resident.label}が、まちにやってきました！'
                    : '${resident.label}とまた出会いました！',
                key: const ValueKey('gacha-result'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '累計${collection.counts[resident.id]}回',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final resident in collection.owned)
                SizedBox(
                  width: 92,
                  child: Column(
                    children: [
                      TownResidentAvatar(resident: resident, size: 60),
                      Text(resident.label, textAlign: TextAlign.center),
                      Text(
                        '累計${collection.counts[resident.id]}回',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
