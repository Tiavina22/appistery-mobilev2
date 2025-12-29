import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Obtenir l'ID unique de l'appareil
  Future<String> getDeviceId() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown';
      }
    } catch (e) {
      print('Erreur obtention device ID: $e');
    }
    return 'unknown';
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
      print('Erreur obtention device name: $e');
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
      print('Erreur obtention IP publique: $e');
      // Essayer un service alternatif
      try {
        final response = await http
            .get(Uri.parse('https://checkip.amazonaws.com'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          return response.body.trim();
        }
      } catch (e2) {
        print('Erreur service alternatif IP: $e2');
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
      print('Erreur obtention user agent: $e');
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
