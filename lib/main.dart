import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'celebration.dart';
import 'progress.dart';
import 'home_skin.dart';
import 'game_home.dart';
import 'missions_screen.dart';
import 'history_screen.dart';
import 'debug_menu_screen.dart';
import 'resident_collection.dart';
import 'resident_gacha.dart';
import 'gacha_hud.dart';
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
  final _townSceneKey = GlobalKey();
  int _page = 0;
  MissionPeriod _missionPeriod = MissionPeriod.daily;
  Mission _previewMission = Mission.strength;
  int _homeVisit = 0;
  bool _celebrating = false;
  Timer? _midnight;
  final _tipIndex = <TownResident, int>{};
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
    final beforeTickets = controller.progress!.residents.earnedTickets(
      controller.progress!.points,
    );
    final earned = await controller.complete(mission);
    if (!mounted || !earned) return;
    _celebrating = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Celebration(
        missionTitle: mission.title,
        total: controller.progress!.points,
        residents: controller.progress!.residents.owned,
        ticketEarned:
            controller.progress!.residents.earnedTickets(
              controller.progress!.points,
            ) >
            beforeTickets,
      ),
    );
    _celebrating = false;
    // Also catches a midnight that occurred while saving or celebrating.
    await controller.refreshDay();
  }

  /// Replays the celebration without touching the progress store.
  Future<void> _previewCelebration() async {
    if (!kDebugMode ||
        _celebrating ||
        controller.busy ||
        controller.failure != null ||
        controller.progress == null) {
      return;
    }
    final total = controller.progress!.points;
    final missionTitle = _previewMission.title;
    _celebrating = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Celebration(
          missionTitle: missionTitle,
          total: total,
          preview: true,
          residents: controller.progress!.residents.owned,
        ),
      );
    } finally {
      _celebrating = false;
    }
  }

  Future<void> _showTip(TownResident resident) async {
    final index = _tipIndex[resident] ?? 0;
    final tip = resident.tips[index % resident.tips.length];
    _tipIndex[resident] = index + 1;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            TownResidentAvatar(resident: resident, size: 48),
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
                        'ことほぎの加算と操作を停止しています。\n'
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
                      period: _missionPeriod,
                      onPeriodChanged: (period) =>
                          setState(() => _missionPeriod = period),
                    )
                  : _page == 2
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/gacya/bg.png',
                            key: const ValueKey('town-page-shrine-background'),
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                        ),
                        PinnedGachaHud(
                          points: progress.points,
                          tickets: progress.residents.tickets(progress.points),
                          ticketBadgeKey:
                              const ValueKey('town-header-ticket-counter'),
                          contentBuilder: (context, availableHeight) => ListView(
                            key: ValueKey('page-$_page'),
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
                            children: _town(progress),
                          ),
                        ),
                      ],
                    )
                  : _page == 3
                  ? HistoryScreen(
                      progress: progress,
                      busy: controller.busy,
                      onClear: () async {
                        await controller.clearHistory();
                      },
                    )
                  : DebugMenuScreen(
                      progress: progress,
                      selectedMission: _previewMission,
                      onMissionChanged: (mission) =>
                          setState(() => _previewMission = mission),
                      onPreview: _previewCelebration,
                      onResetAll: controller.resetAllMissionsForDebug,
                      onAddTickets: controller.grantTicketsForDebug,
                      busy: controller.busy || _celebrating,
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
            const NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined, size: 35),
              label: '履歴',
            ),
            if (kDebugMode)
              NavigationDestination(
                icon: uiPart('21_nav_menu', width: 54, height: 58),
                label: 'メニュー',
              ),
          ],
        ),
      );
    },
  );

  List<Widget> _town(Progress progress) => [
    Container(
      key: const ValueKey('town-page-title-panel'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: parchment(),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'みんなのまち',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: wood,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'あなたの行動が、まちの彩りに。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF82583B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 22),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: parchment(),
      child: Row(
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    TownScene(
      key: _townSceneKey,
      level: progress.townLevel,
      residents: progress.residents.owned,
      onResident: _showTip,
    ),
    const SizedBox(height: 14),
    Text(
      townDescriptions[progress.townLevel],
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 24),
    ResidentGacha(
      controller: controller,
      onTown: () {
        final scene = _townSceneKey.currentContext;
        if (scene != null) Scrollable.ensureVisible(scene);
      },
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
      'ことほぎは社会貢献をイメージしたゲーム内の値です。\n実際の介護費削減額や個人の健康効果を示すものではありません。',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: Color(0xFF627875), height: 1.6),
    ),
  ];
}
