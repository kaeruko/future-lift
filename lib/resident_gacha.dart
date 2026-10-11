import 'package:flutter/material.dart';

import 'progress.dart';
import 'resident_collection.dart';
import 'home_skin.dart';
import 'gacha_reveal.dart';

/// Inline panel keeps save failures visible on the main diagnostic screen.
class ResidentGacha extends StatefulWidget {
  const ResidentGacha({super.key, required this.controller, this.onTown});
  final VoidCallback? onTown;
  final ProgressController controller;
  @override
  State<ResidentGacha> createState() => _ResidentGachaState();
}

class _ResidentGachaState extends State<ResidentGacha> {
  bool _revealing = false;

  Future<void> _draw() async {
    if (_revealing) return;
    setState(() => _revealing = true);
    final before = widget.controller.progress!.residents.counts;
    final result = await widget.controller.drawResident();
    if (!mounted) return;
    if (result == null) {
      setState(() => _revealing = false);
      return;
    }
    final town = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GachaReveal(
          controller: widget.controller,
          resident: result,
          isNew: !before.containsKey(result.id),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _revealing = false);
    if (town == true) widget.onTown?.call();
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
            onPressed: _revealing || widget.controller.busy || tickets == 0
                ? null
                : _draw,
            icon: const Icon(Icons.celebration_outlined),
            label: Text(widget.controller.busy ? '住民を迎えています…' : '住民を迎える（券1枚）'),
          ),
          const SizedBox(height: 8),
          const Text(
            '全6種類が同じ確率（各1/6）で登場します。\n同じ住民と再会することもあります。',
            style: TextStyle(fontSize: 12),
          ),
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
