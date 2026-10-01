import 'package:package_info_plus/package_info_plus.dart';

/// Common class to manage app version details across the application.
class AppVersionInfo {
  static String _version = '1.0.0';
  static String _buildNumber = '1';
  static String _appName = 'Hyper Hitter';
  static String _packageName = '';
  static bool _isInitialized = false;

  /// Initializes package information asynchronously from the platform.
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isNotEmpty) {
        _version = packageInfo.version;
      }
      if (packageInfo.buildNumber.isNotEmpty) {
        _buildNumber = packageInfo.buildNumber;
      }
      if (packageInfo.appName.isNotEmpty) {
        _appName = packageInfo.appName;
      }
      if (packageInfo.packageName.isNotEmpty) {
        _packageName = packageInfo.packageName;
      }
      _isInitialized = true;
    } catch (_) {
      _isInitialized = true;
    }
  }

  /// App version string (e.g. "1.0.0")
  static String get version => _version;

  /// App build number (e.g. "1")
  static String get buildNumber => _buildNumber;

  /// App name
  static String get appName => _appName;

  /// Package / Bundle ID
  static String get packageName => _packageName;

  /// Formatted version with build number (e.g. "v1.0.0 (1)")
  static String get fullVersion => 'v$_version ($_buildNumber)';

  /// Simple version label (e.g. "Version 1.0.0")
  static String get displayVersion => 'Version $_version';
}
