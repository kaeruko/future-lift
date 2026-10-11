import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_lift/resident_collection.dart';
import 'package:future_lift/town.dart';
import 'package:future_lift/town_walk.dart';

void main() {
  test('every stroll stays inside the plaza and cycles through all directions', () {
    for (var index = 0; index < townWalkSlots.length; index++) {
      final directions = <WalkDirection>{};
      var pauses = 0;
      for (var millis = 0; millis < 25600; millis += 150) {
        final pose = townWalkPose(index, Duration(milliseconds: millis));
        // A sprite takes at most 14% of the width and ~18% of height.
        expect(pose.x, inInclusiveRange(0, .86), reason: 'slot $index');
        expect(pose.y, inInclusiveRange(0, .82), reason: 'slot $index');
        expect(pose.frame, inInclusiveRange(0, 3));
        if (pose.direction case final direction?) {
          directions.add(direction);
        } else {
          pauses++;
        }
      }
      expect(directions, WalkDirection.values.toSet());
      expect(pauses, greaterThan(0));
    }
    expect(townWalkPose(0, Duration.zero).direction, WalkDirection.right);
    expect(townWalkPose(0, const Duration(milliseconds: 3000)).walking, false);
    expect(townWalkPose(0, const Duration(milliseconds: 3900)).direction,
        WalkDirection.front);
    expect(townWalkPose(0, const Duration(milliseconds: 6400)).direction,
        WalkDirection.left);
    expect(townWalkPose(0, const Duration(milliseconds: 10300)).direction,
        WalkDirection.back);
    expect(townWalkPose(0, const Duration(milliseconds: 12800)).direction,
        WalkDirection.right);
    expect(() => townWalkPose(-1, Duration.zero), throwsRangeError);
    expect(() => townWalkPose(8, Duration.zero), throwsRangeError);
  });

  test('sprite directions use the real files, shiba mirrors left explicitly', () {
    for (final resident in TownResident.values) {
      for (final direction in WalkDirection.values) {
        for (var frame = 0; frame < 4; frame++) {
          final path = resident.walkAsset(direction, frame);
          final suffix = (frame + 1).toString().padLeft(2, '0');
          final assetDirection = direction == WalkDirection.left &&
                  resident == TownResident.shiba
              ? 'right'
              : direction.name;
          expect(path, endsWith('walk_${assetDirection}_$suffix.png'));
        }
      }
      expect(resident.mirrorWalk(WalkDirection.left),
          resident == TownResident.shiba);
      expect(() => resident.walkAsset(WalkDirection.front, -1),
          throwsRangeError);
      expect(() => resident.walkAsset(WalkDirection.front, 4),
          throwsRangeError);
    }
  });

  testWidgets('all referenced walking PNGs are bundled with Flutter', (tester) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final resident in TownResident.values) {
      expect(manifest.listAssets().contains(resident.idleAsset), true);
      for (final direction in WalkDirection.values) {
        for (var frame = 0; frame < 4; frame++) {
          final asset = resident.walkAsset(direction, frame);
          expect(manifest.listAssets().contains(asset), true,
              reason: 'Missing $asset in pubspec.yaml');
        }
      }
    }
  });

  testWidgets('walkers move with sprites and pause while talking', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gate = Completer<void>();
    var conversations = 0;
    Widget scene(List<TownResident> residents) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: TownScene(
              level: 0,
              residents: residents,
              onResident: (_) async {
                conversations++;
                await gate.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(scene([TownResident.shiba, TownResident.rabbit]));
    final shiba = find.byKey(const ValueKey('resident-0'));
    final sprite = find.byKey(const ValueKey('resident-sprite-0'));
    expect(shiba, findsOneWidget);
    expect(find.byKey(const ValueKey('resident-1')), findsOneWidget);
    AssetImage source() => tester.widget<Image>(sprite).image as AssetImage;
    expect(source().assetName, TownResident.shiba.walkAsset(WalkDirection.right, 0));
    final initialPosition = tester.getTopLeft(shiba);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getTopLeft(shiba).dx, greaterThan(initialPosition.dx));
    expect(source().assetName, contains('/walk_right_'));
    await tester.tap(shiba);
    await tester.pump();
    expect(conversations, 1);
    expect(source().assetName, TownResident.shiba.idleAsset);
    final stoppedAt = tester.getTopLeft(shiba);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(shiba), stoppedAt);
    expect(source().assetName, TownResident.shiba.idleAsset);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(source().assetName, contains('/walk_right_'));
    expect(tester.getTopLeft(shiba).dx, greaterThan(stoppedAt.dx));

    // Gacha additions also get their own independent walker.
    await tester.pumpWidget(scene([
      TownResident.shiba, TownResident.rabbit, TownResident.penguin,
    ]));
    expect(find.byKey(const ValueKey('resident-2')), findsOneWidget);
    // The penguin joins during its natural rest phase, then starts walking.
    final joiningSprite = tester.widget<Image>(
      find.byKey(const ValueKey('resident-sprite-2')),
    );
    expect((joiningSprite.image as AssetImage).assetName,
        TownResident.penguin.idleAsset);
    await tester.pump(const Duration(milliseconds: 900));
    final walkingSprite = tester.widget<Image>(
      find.byKey(const ValueKey('resident-sprite-2')),
    );
    expect((walkingSprite.image as AssetImage).assetName,
        contains('/walk_front_'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced-motion mode shows only idle sprites', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const TownScene(
                level: 0,
                residents: [TownResident.shiba, TownResident.rabbit],
              ),
            ),
          ),
        ),
      ),
    );
    final sprite = find.byKey(const ValueKey('resident-sprite-0'));
    final shiba = find.byKey(const ValueKey('resident-0'));
    final initialPosition = tester.getTopLeft(shiba);
    expect((tester.widget<Image>(sprite).image as AssetImage).assetName,
        TownResident.shiba.idleAsset);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.getTopLeft(shiba), initialPosition);
    expect((tester.widget<Image>(sprite).image as AssetImage).assetName,
        TownResident.shiba.idleAsset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
