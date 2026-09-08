import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = 'https://api.smartpay.click/apk';

  Future<Map<String, dynamic>?> trackDevice(
    Map<String, dynamic> deviceData,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/devices/track'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(deviceData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ [API] trackDevice Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLockStatus(String imei) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/devices/$imei/lock-status'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } on SocketException {
      debugPrint('🌐 [API] No Internet connection or server unreachable.');
      return null;
    } on TimeoutException {
      debugPrint('⏳ [API] Connection timed out.');
      return null;
    } catch (e) {
      // Software caused connection abort হ্যান্ডেল করা হচ্ছে
      debugPrint('⚠️ [API] getLockStatus Exception: $e');
      return null;
    }
  }
}
