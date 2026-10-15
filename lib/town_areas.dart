import 'resident_collection.dart';

/// Each neighborhood owns its residents and its independently sourced artwork.
/// The user's selected area is UI-only; no progress save migration is required.
enum TownArea {
  plaza('plaza', '中央ひろば', 'みんなが集まるまちの中心。', 0,
      'assets/kotohogu/town_background_001.jpg'),
  park('park', 'ふれあい公園', 'お散歩やおしゃべりを楽しむ場所。', 90, null),
  shopping('shopping', 'ことほぎ商店街', 'お店と仕事の話が聞こえてくる通り。', 180, null),
  village('village', 'のんびり里', '畑とおうちで、それぞれのペースで暮らす場所。', 300, null);

  const TownArea(this.id, this.label, this.description, this.unlockAt,
      this.backgroundAsset);

  final String id;
  final String label;
  final String description;
  /// Earned lifetime mission points, never the spendable currency balance.
  final int unlockAt;
  /// No fallback to another area's artwork when this is null.
  final String? backgroundAsset;

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
