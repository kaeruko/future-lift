import 'resident_collection.dart';

/// Each neighborhood owns its residents and its independently sourced artwork.
/// The user's selected area is UI-only; no progress save migration is required.
enum TownArea {
  plaza('plaza', '中央ひろば', 'みんなが集まるまちの中心。', 0,
      'assets/kotohogu/town_background_001.jpg', 768, 1376),
  park('park', 'ふれあい公園', 'お散歩やおしゃべりを楽しむ場所。', 90,
      'assets/kotohogu/park_background_001.png', 937, 1679),
  shopping('shopping', 'ことほぎ商店街', 'お店と仕事の話が聞こえてくる通り。', 180,
      'assets/kotohogu/street_background_001.png', 937, 1679),
  village('village', 'のんびり里', '畑とおうちで、それぞれのペースで暮らす場所。', 300,
      'assets/kotohogu/village_background_001.png', 941, 1672);

  const TownArea(this.id, this.label, this.description, this.unlockAt,
      this.backgroundAsset, this.sourceWidth, this.sourceHeight);

  final String id;
  final String label;
  final String description;
  /// Earned lifetime mission points, never the spendable currency balance.
  final int unlockAt;
  /// No fallback to another area's artwork when this is null.
  final String? backgroundAsset;
  /// Intrinsic pixels for the matching background asset, not a shared canvas.
  /// The artwork and its walkers must share this source coordinate system.
  final int? sourceWidth;
  final int? sourceHeight;

  bool isUnlocked(int lifetimePoints) => lifetimePoints >= unlockAt;

  static TownArea fromId(String id) => values.firstWhere(
    (area) => area.id == id,
    orElse: () => throw FormatException('Unknown town area ID: $id'),
  );
}

/// An area receives up to eight residents *after* filtering by home.
List<TownResident> areaResidents(
  Iterable<TownResident> owned,
  TownArea area, {
  List<TownResident>? debugOverride,
}) {
  final candidates = debugOverride == null
      ? owned.where((resident) => resident.walkInTown)
      : visibleTownResidents(owned, debugOverride: debugOverride);
  return List<TownResident>.unmodifiable(
    candidates.where((resident) => resident.homeAreaId == area.id)
        .take(townResidentLimit),
  );
}
