import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _fallbackDeviceIdKey = 'fallback_device_id';

  // Génère un UUID v4 aléatoire
  String _generateUUID() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  // Obtenir ou créer un ID de secours persistant
  Future<String> _getOrCreateFallbackId() async {
    try {
      final existing = await _storage.read(key: _fallbackDeviceIdKey);
      if (existing != null && existing.isNotEmpty) return existing;
      final newId = _generateUUID();
      await _storage.write(key: _fallbackDeviceIdKey, value: newId);
      return newId;
    } catch (_) {
      return _generateUUID();
    }
  }

  // Obtenir l'ID unique de l'appareil
  Future<String> getDeviceId() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        final id = androidInfo.id;
        if (id.isNotEmpty) return id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final id = iosInfo.identifierForVendor;
        if (id != null && id.isNotEmpty) return id;
      }
    } catch (_) {}
    // Fallback : UUID persistant généré localement
    return _getOrCreateFallbackId();
  }

  // Obtenir le nom de l'appareil
  Future<String> getDeviceName() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.utsname.machine;
      }
    } catch (e) {
    }
    return 'Unknown Device';
  }

  // Obtenir l'adresse IP publique
  Future<String?> getPublicIpAddress() async {
    try {
      // Utiliser un service public pour obtenir l'IP
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ip'] as String?;
      }
    } catch (e) {
      // Essayer un service alternatif
      try {
        final response = await http
            .get(Uri.parse('https://checkip.amazonaws.com'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          return response.body.trim();
        }
      } catch (e2) {
      }
    }
    return null;
  }

  // Obtenir le user agent
  Future<String> getUserAgent() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release} - ${androidInfo.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion} - ${iosInfo.model}';
      }
    } catch (e) {
    }
    return 'Unknown';
  }

  // Obtenir toutes les infos d'appareil
  Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();
    final ipAddress = await getPublicIpAddress();
    final userAgent = await getUserAgent();

    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'ip_address': ipAddress,
      'user_agent': userAgent,
    };
  }
}
