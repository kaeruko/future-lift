import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'celebration.dart';
import 'progress.dart';
import 'residents.dart';
import 'town.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    FutureLiftApp(
      controller: ProgressController(
        LocalProgressStore(SharedPreferencesAsync()),
      ),
    ),
  );
}

const ink = Color(0xFF284F50);
const teal = Color(0xFF277A70);
const orange = Color(0xFFBF4E27);
const cream = Color(0xFFFFFAF0);

class FutureLiftApp extends StatelessWidget {
  const FutureLiftApp({super.key, required this.controller});
  final ProgressController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FutureLift',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: teal, surface: cream),
      scaffoldBackgroundColor: cream,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFDDEFE7),
      ),
    ),
    home: FutureLiftHome(controller: controller),
  );
}

class FutureLiftHome extends StatefulWidget {
  const FutureLiftHome({super.key, required this.controller});
  final ProgressController controller;

  @override
  State<FutureLiftHome> createState() => _FutureLiftHomeState();
}

class _FutureLiftHomeState extends State<FutureLiftHome>
    with WidgetsBindingObserver {
  int _page = 0;
  bool _celebrating = false;
  Timer? _midnight;
  final _tipIndex = <Resident, int>{};
  ProgressController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.initialize();
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = controller.clock().toLocal();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(tomorrow.difference(now), () async {
      await controller.refreshDay();
      if (mounted) _scheduleMidnight();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.refreshDay();
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _complete(Mission mission) async {
    if (_celebrating) return;
    final earned = await controller.complete(mission);
    if (!mounted || !earned) return;
    _celebrating = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Celebration(
        missionTitle: mission.title,
        total: controller.progress!.points,
      ),
    );
    _celebrating = false;
    // Also catches a midnight that occurred while saving or celebrating.
    await controller.refreshDay();
  }

  void _showTip(Resident resident) {
    final index = _tipIndex[resident] ?? 0;
    final tip = resident.tips[index % resident.tips.length];
    _tipIndex[resident] = index + 1;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            ResidentAvatar(resident: resident, size: 48),
            const SizedBox(width: 12),
            Expanded(child: Text(resident.label)),
          ],
        ),
        content: Text(tip, style: const TextStyle(fontSize: 19, height: 1.8)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('また話そう'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      if (controller.failure case final failure?) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 44,
                        color: teal,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '記録を確認できないため、停止しました',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '読み込み・保存・日付の確認で問題が起きました。\n'
                        'ポイントの加算と操作を停止しています。\n'
                        '以下の診断情報を確認し、原因を解消してからアプリを再起動してください。',
                      ),
                      const SizedBox(height: 24),
                      ExpansionTile(
                        title: const Text('診断情報'),
                        children: [
                          SelectableText(
                            failure.diagnostics,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      final progress = controller.progress;
      if (progress == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                key: ValueKey('page-$_page'),
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: teal,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.spa_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'FutureLift',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Text(
                          'セルフケアは、\n社会貢献。',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  if (_page == 0) ..._home(progress) else ..._town(progress),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _page,
          onDestinationSelected: (index) => setState(() => _page = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined),
              selectedIcon: Icon(Icons.wb_sunny_rounded),
              label: '今日のミッション',
            ),
            NavigationDestination(
              icon: Icon(Icons.holiday_village_outlined),
              selectedIcon: Icon(Icons.holiday_village_rounded),
              label: 'みんなのまち',
            ),
          ],
        ),
      );
    },
  );

  Widget _points(Progress progress) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFFE6F1E9),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const Icon(Icons.favorite_rounded, color: teal, size: 22),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'これまでの社会貢献',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '${progress.points}',
          key: const ValueKey('total-points'),
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w900,
            color: teal,
          ),
        ),
        const Text(
          ' pt',
          style: TextStyle(color: teal, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  List<Widget> _home(Progress progress) => [
    const Text(
      '今日の小さな行動が、\n誰かの未来につながる。',
      style: TextStyle(
        fontSize: 28,
        height: 1.45,
        fontWeight: FontWeight.w900,
        letterSpacing: -.5,
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      'あなたのペースで。できたことを、ひとつずつ。',
      style: TextStyle(fontSize: 13, color: Color(0xFF627875)),
    ),
    const SizedBox(height: 20),
    _points(progress),
    const SizedBox(height: 26),
    Row(
      children: [
        const Expanded(
          child: Text(
            '今日のミッション',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          '${int.parse(progress.day.substring(5, 7))}月${int.parse(progress.day.substring(8))}日',
          style: const TextStyle(color: Color(0xFF627875)),
        ),
      ],
    ),
    const SizedBox(height: 14),
    for (final mission in Mission.values) _missionCard(mission, progress),
    const SizedBox(height: 10),
    const Text(
      '量や回数は問いません。今日行動したことを祝います。',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: Color(0xFF627875)),
    ),
    const SizedBox(height: 24),
    Material(
      color: const Color(0xFFF4EBD9),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => setState(() => _page = 1),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.holiday_village_rounded, color: teal, size: 38),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'みんなのまちへ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      townNames[progress.townLevel],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: teal),
            ],
          ),
        ),
      ),
    ),
  ];

  Widget _missionCard(Mission mission, Progress progress) {
    final done = progress.completed.contains(mission);
    final icon = switch (mission) {
      Mission.strength => Icons.accessibility_new_rounded,
      Mission.outside => Icons.directions_walk_rounded,
      Mission.conversation => Icons.forum_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: done ? const Color(0xFFACD7C8) : const Color(0xFFF0E7D9),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D3841),
            offset: Offset(0, 5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEECF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF8B6026), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mission.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (done) const Icon(Icons.check_circle_rounded, color: teal),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            mission.description,
            style: const TextStyle(color: Color(0xFF627875), fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: ValueKey('complete-${mission.name}'),
              style: FilledButton.styleFrom(
                backgroundColor: orange,
                disabledBackgroundColor: const Color(0xFFE6F1E9),
                disabledForegroundColor: teal,
                minimumSize: const Size(0, 58),
              ),
              onPressed: done || controller.busy
                  ? null
                  : () => _complete(mission),
              child: Text(
                done ? 'できた！  達成済み' : 'できた！',
                style: TextStyle(
                  fontSize: done ? 18 : 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _town(Progress progress) => [
    const Text(
      'みんなのまち',
      style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
    ),
    const SizedBox(height: 8),
    const Text('あなたの行動が、まちの彩りに。', style: TextStyle(color: Color(0xFF627875))),
    const SizedBox(height: 20),
    _points(progress),
    const SizedBox(height: 20),
    Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: teal,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'LEVEL ${progress.townLevel}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            townNames[progress.townLevel],
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    TownScene(level: progress.townLevel, onResident: _showTip),
    const SizedBox(height: 14),
    Text(
      townDescriptions[progress.townLevel],
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 24),
    const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_outlined, color: teal),
        SizedBox(width: 6),
        Flexible(child: Text('住民をタップして、おしゃべりしよう。')),
      ],
    ),
    const SizedBox(height: 22),
    const Text(
      'まちは、休んでもそのまま。\nまた来たい日に、会いにきてください。',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0xFF627875), height: 1.8),
    ),
    const SizedBox(height: 18),
    const Text(
      'ポイントは社会貢献を表すゲーム内の表現です。\n実際の介護費削減額や個人の健康効果を示すものではありません。',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: Color(0xFF627875), height: 1.6),
    ),
  ];
}
