import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/usage_service.dart';
import '../../../core/utils/constants.dart';
import '../domain/drill_program.dart';

/// All Reaction Drill programs: built-in ones from
/// `assets/drills/programs.json` plus the user's own drills (same JSON
/// format, saved on the phone). Also remembers the drill picked for the next
/// session ([active]), which the drill session reads.
class DrillService extends GetxService {
  static DrillService get to => Get.find();

  static const String builtInAsset = 'assets/drills/programs.json';
  static const String _kCustom = 'custom_drills_v1';
  static const String _kLastId = 'last_drill_id';

  final RxList<DrillProgram> builtIn = <DrillProgram>[].obs;
  final RxList<DrillProgram> custom = <DrillProgram>[].obs;

  /// The drill (with the user's round choice) for the next session.
  final Rxn<DrillProgram> active = Rxn<DrillProgram>();

  Future<void>? _loading;

  /// Used if the JSON can't be read, so the drill always works.
  static final DrillProgram fallback = DrillProgram(
    id: 'beginner',
    title: 'Beginner',
    category: 'basic',
    combos: AppConstants.comboList,
    callIntervalMs: 1200,
  );

  List<DrillProgram> get all => [...builtIn, ...custom];

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      builtIn.assignAll(
        parseList(jsonDecode(await rootBundle.loadString(builtInAsset))),
      );
    } catch (_) {
      builtIn.assignAll([fallback]);
    }
    if (builtIn.isEmpty) builtIn.add(fallback);
    try {
      custom.assignAll(
        parseList(jsonDecode(StorageService.to.getString(_kCustom) ?? '[]')),
      );
    } catch (_) {
      custom.clear();
    }
    active.value ??=
        byId(StorageService.to.getString(_kLastId)) ?? builtIn.first;
  }

  /// Accepts `{"programs": [...]}` or a plain list; skips bad entries.
  static List<DrillProgram> parseList(Object? decoded) {
    final list = decoded is Map ? decoded['programs'] : decoded;
    if (list is! List) return [];
    return [for (final raw in list) ?DrillProgram.tryParse(raw)];
  }

  DrillProgram? byId(String? id) {
    if (id == null) return null;
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Picks the drill for the next session.
  void select(DrillProgram program) {
    active.value = program;
    StorageService.to.setString(_kLastId, program.id);
  }

  // ─── Free / Pro ──────────────────────────────────────────────────────────

  bool get _isPro => UsageService.to.isPro.value;

  /// The drill needs Pro and the user isn't Pro (only when locking is on).
  bool isLocked(DrillProgram p) =>
      AppConstants.lockProDrills && p.proOnly && !_isPro;

  /// Free users can keep [AppConstants.freeCustomDrills] own drills.
  bool get canCreateCustom =>
      !AppConstants.lockProDrills ||
      _isPro ||
      custom.length < AppConstants.freeCustomDrills;

  // ─── Own drills ──────────────────────────────────────────────────────────

  Future<void> saveCustom(DrillProgram program) async {
    final p = program.copyWith(category: 'custom', proOnly: false);
    final i = custom.indexWhere((c) => c.id == p.id);
    if (i >= 0) {
      custom[i] = p;
    } else {
      custom.add(p);
    }
    if (active.value?.id == p.id) active.value = p;
    await _persistCustom();
  }

  Future<void> deleteCustom(String id) async {
    custom.removeWhere((c) => c.id == id);
    if (active.value?.id == id) active.value = builtIn.first;
    await _persistCustom();
  }

  Future<void> _persistCustom() => StorageService.to.setString(
    _kCustom,
    jsonEncode([for (final c in custom) c.toJson()]),
  );

  static String newCustomId() =>
      'custom_${DateTime.now().microsecondsSinceEpoch}';
}
