import 'package:flutter/material.dart';
import '../services/version_service.dart';

class VersionProvider extends ChangeNotifier {
  final VersionService _versionService = VersionService();

  bool _isUpdateRequired = false;
  bool _isVersionExpired = false;
  bool _noActiveVersion = false;
  String? _downloadUrl;
  String? _versionName;
  String? _description;
  DateTime? _endDate;
  bool _isChecking = false;
  String? _errorMessage;

  // Getters
  bool get isUpdateRequired => _isUpdateRequired;
  bool get isVersionExpired => _isVersionExpired;
  bool get noActiveVersion => _noActiveVersion;
  String? get downloadUrl => _downloadUrl;
  String? get versionName => _versionName;
  String? get description => _description;
  DateTime? get endDate => _endDate;
  bool get isChecking => _isChecking;
  String? get errorMessage => _errorMessage;

  /// Check app version at startup
  Future<void> checkVersionAtStartup() async {
    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final versionCode = VersionService.getAppVersionCode();
      final platform = VersionService.getAppPlatform();

      print('📱 Checking version... Code: $versionCode, Platform: $platform');

      final versionInfo = await _versionService.checkVersion(
        versionCode: versionCode,
        platform: platform,
      );

      print('✅ Version check response: $versionInfo');

      // Check if no active version is available
      if (versionInfo.isEmpty || versionInfo['currentVersion'] == null) {
        _noActiveVersion = true;
        _isUpdateRequired = false;
        _isVersionExpired = false;
        // Extract fallback data even when no active version
        _downloadUrl = versionInfo['downloadUrl'];
        _versionName = versionInfo['versionName'];
        _description = versionInfo['description'];
        print('⚠️ No active version found - app is blocked');
      } else {
        _noActiveVersion = false;
        _isUpdateRequired = versionInfo['isUpdateRequired'] ?? false;
        _isVersionExpired = versionInfo['isVersionExpired'] ?? false;
        _downloadUrl = versionInfo['downloadUrl'];
        _versionName = versionInfo['versionName'];
        _description = versionInfo['description'];
      }

      if (versionInfo['endDate'] != null) {
        _endDate = DateTime.parse(versionInfo['endDate']);
      }

      print('📊 Version state updated:');
      print('   isUpdateRequired: $_isUpdateRequired');
      print('   isVersionExpired: $_isVersionExpired');
      print('   downloadUrl: $_downloadUrl');
      print('   versionName: $_versionName');
    } catch (e) {
      _errorMessage = 'Failed to check version: $e';
      print('❌ Error checking version: $e');

      // Check if error is due to no active version (404/400)
      if (e.toString().contains('404') || e.toString().contains('400')) {
        _noActiveVersion = true;
        print('⚠️ No active version found - app blocked');
      } else {
        // Don't block the app on other version check failures
        _noActiveVersion = false;
      }
      _isUpdateRequired = false;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Reset version state
  void resetVersionState() {
    _isUpdateRequired = false;
    _isVersionExpired = false;
    _noActiveVersion = false;
    _downloadUrl = null;
    _versionName = null;
    _description = null;
    _endDate = null;
    _errorMessage = null;
    notifyListeners();
  }
}
