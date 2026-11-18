import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/sensitivity_level.dart';

/// Room-noise calibration kept for the rest of the day so the next session
/// can skip the 5-second quiet check.
class SavedCalibration {
  final double maxDb;
  final double avgDb;

  const SavedCalibration({required this.maxDb, required this.avgDb});
}

/// App-wide key/value persistence (first-run flag, developer mode, daily
/// usage, saved setup). Initialised once in `main()` before `runApp`.
class StorageService extends GetxService {
  static const String _kOnboardingDone = 'onboarding_done';
  static const String _kDeveloperMode = 'developer_mode';
  static const String _kUsageDate = 'usage_date';
  static const String _kUsagePunches = 'usage_punches';
  static const String _kSensitivity = 'sensitivity';
  static const String _kDifficulty = 'prompt_difficulty';
  static const String _kCalibrationDate = 'calibration_date';
  static const String _kCalibrationMaxDb = 'calibration_max_db';
  static const String _kCalibrationAvgDb = 'calibration_avg_db';
  static const String _kSouthpaw = 'southpaw';
  static const String _kLastSessionEndMs = 'last_session_end_ms';

  late final SharedPreferences _prefs;

  final RxBool developerMode = false.obs;

  /// Left-handed stance: the bag targets mirror left↔right.
  final RxBool southpaw = false.obs;

  static StorageService get to => Get.find<StorageService>();

  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    developerMode.value = _prefs.getBool(_kDeveloperMode) ?? false;
    southpaw.value = _prefs.getBool(_kSouthpaw) ?? false;
    return this;
  }

  Future<void> setSouthpaw(bool value) async {
    southpaw.value = value;
    await _prefs.setBool(_kSouthpaw, value);
  }

  bool get onboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool value) =>
      _prefs.setBool(_kOnboardingDone, value);

  Future<void> setDeveloperMode(bool value) async {
    developerMode.value = value;
    await _prefs.setBool(_kDeveloperMode, value);
  }

  SensitivityLevel get sensitivity =>
      SensitivityLevel.fromId(_prefs.getString(_kSensitivity));
  Future<void> setSensitivity(SensitivityLevel level) =>
      _prefs.setString(_kSensitivity, level.id);

  /// Last prompt-drill difficulty: 'beginner', 'intermediate' or 'advanced'.
  String get difficulty => _prefs.getString(_kDifficulty) ?? 'beginner';
  Future<void> setDifficulty(String value) =>
      _prefs.setString(_kDifficulty, value);

  /// Last good room check. The room is measured before every session; this is
  /// only the backup for when the microphone gives no samples.
  SavedCalibration? get lastCalibration {
    final maxDb = _prefs.getDouble(_kCalibrationMaxDb);
    final avgDb = _prefs.getDouble(_kCalibrationAvgDb);
    if (maxDb == null || avgDb == null) return null;
    return SavedCalibration(maxDb: maxDb, avgDb: avgDb);
  }

  Future<void> saveCalibration(SavedCalibration calibration) async {
    await _prefs.setString(_kCalibrationDate, _todayKey());
    await _prefs.setDouble(_kCalibrationMaxDb, calibration.maxDb);
    await _prefs.setDouble(_kCalibrationAvgDb, calibration.avgDb);
  }

  /// When the last session finished (Results opened), for Quick start.
  DateTime? get lastSessionEnd {
    final ms = _prefs.getInt(_kLastSessionEndMs);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastSessionEnd(DateTime at) =>
      _prefs.setInt(_kLastSessionEndMs, at.millisecondsSinceEpoch);

  /// Punches counted today; resets when the stored date is not today.
  int get todayPunches {
    if (_prefs.getString(_kUsageDate) != _todayKey()) return 0;
    return _prefs.getInt(_kUsagePunches) ?? 0;
  }

  Future<void> setTodayPunches(int value) async {
    // Start both writes at once: SharedPreferences updates its cache when a
    // write starts, so [todayPunches] is current immediately, even when punches
    // arrive faster than the disk writes finish.
    await Future.wait([
      _prefs.setString(_kUsageDate, _todayKey()),
      _prefs.setInt(_kUsagePunches, value),
    ]);
  }

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
