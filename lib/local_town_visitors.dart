import 'local_content_preview.dart';
import 'resident_collection.dart';
import 'town_areas.dart';

/// HTTP visitors are session-only and excluded from gacha and saves.
List<RemoteResident> localVisitorsForArea(
  RemoteContentCatalog catalog,
  TownArea area, {
  required int lifetimePoints,
  required Iterable<TownResident> owned,
  bool debugTownSelectionActive = false,
}) {
  if (debugTownSelectionActive) return const [];
  final ownedIds = owned.map((resident) => resident.id).toSet();
  final builtInIds = TownResident.values.map((resident) => resident.id).toSet();
  final candidates = catalog.characters.where((resident) {
    if (!resident.walkInTown || ownedIds.contains(resident.id)) return false;
    final home = TownArea.fromId(resident.homeAreaId);
    final current = home.isUnlocked(lifetimePoints) ? home : TownArea.plaza;
    return current == area;
  }).toList();

  // Every truly new resident appears; showcase one unowned built-in resident
  // per area to test network sprites even before creating a new character.
  final newResidents = candidates.where(
    (resident) => !builtInIds.contains(resident.id),
  );
  final showcase = candidates.where(
    (resident) => builtInIds.contains(resident.id),
  ).take(1);
  return List<RemoteResident>.unmodifiable([...newResidents, ...showcase]);
}

RemoteDialogue visitorGreeting(RemoteContentCatalog catalog, String residentId) {
  final greetings = catalog.linesFor(residentId)
      .where((line) => line.conditionCount == 0 && !line.once)
      .toList();
  if (greetings.isEmpty) {
    throw StateError('No unconditional visitor greeting: $residentId');
  }
  greetings.sort((a, b) => b.priority.compareTo(a.priority));
  return greetings.first;
}
