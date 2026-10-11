import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'celebration.dart';
import 'progress.dart';
import 'home_skin.dart';
import 'game_home.dart';
import 'missions_screen.dart';
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

const ink = Color(0xFF63351F);
const teal = Color(0xFF277A70);
const orange = Color(0xFFBF4E27);
const cream = Color(0xFFFBEDD3);

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
        backgroundColor: Color(0xFFFFF4DA),
        indicatorColor: Color(0xFFFFD898),
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
  int _homeVisit = 0;
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
              child: _page == 0
                  ? GameHome(
                      key: ValueKey(_homeVisit),
                      progress: progress,
                      onMissions: () => setState(() => _page = 1),
                      onTown: () => setState(() => _page = 2),
                      onResident: _showTip,
                    )
                  : _page == 1
                  ? MissionsScreen(
                      progress: progress,
                      busy: controller.busy,
                      onComplete: _complete,
                    )
                  : ListView(
                      key: ValueKey('page-$_page'),
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: Color(0xFFBD4927),
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
                        ..._town(progress),
                      ],
                    ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 104,
          selectedIndex: _page,
          onDestinationSelected: (index) => setState(() {
            _page = index;
            if (index == 0) _homeVisit++;
          }),
          destinations: [
            NavigationDestination(
              icon: uiPart('09_nav_home', width: 54, height: 58),
              label: 'ホーム',
            ),
            NavigationDestination(
              icon: uiPart('10_nav_quest', width: 54, height: 58),
              label: 'ミッション',
            ),
            NavigationDestination(
              icon: uiPart('11_nav_town', width: 54, height: 58),
              label: 'みんなのまち',
            ),
          ],
        ),
      );
    },
  );

  Widget _points(Progress progress) =>
      ContributionPanel(points: progress.points);

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
