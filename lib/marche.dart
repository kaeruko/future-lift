import 'progress.dart';
import 'resident_collection.dart';

/// The opening conversation is already persisted through seenDialogues.
const tonkoMarcheOpeningDialogueId = '041_pig_middle_033';
const tonkoMarcheGreetingDialogueId = '041_pig_middle_034';
const tonkoMarcheOwner = TownResident.c041_pig_middle;

/// Temporary debug cast membership cannot unlock the real tea stall.
bool isMarcheOpen(Progress progress) =>
    progress.residents.owned.contains(tonkoMarcheOwner) &&
    progress.seenDialogues.contains(tonkoMarcheOpeningDialogueId);
