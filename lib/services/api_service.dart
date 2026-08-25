import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = 'https://api.smartpay.click/apk';

  // লগইনের সময় এই API কল হবে (Track Device)
  Future<Map<String, dynamic>?> trackDevice(Map<String, dynamic> deviceData) async {
    debugPrint('-----------------------');
    debugPrint('🚀 [API] Sending POST Request to: $baseUrl/devices/track');
    debugPrint('-----------------------');

    // প্রতিটি ফিল্ড আলাদা করে প্রিন্ট করা হচ্ছে
    deviceData.forEach((key, value) {
      debugPrint('📤 [API] $key: $value');
    });

    debugPrint('-----------------------');
    debugPrint('📦 [API] Full Payload: ${jsonEncode(deviceData)}');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices/track'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(deviceData),
      ).timeout(const Duration(seconds: 20));

      debugPrint('-----------------------');
      debugPrint('📥 [API] Status Code: ${response.statusCode}');
      debugPrint('📥 [API] Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body);

        // Response এর ভেতরের ডাটা প্রিন্ট করা হচ্ছে
        if (jsonResponse['data'] != null) {
          Map<String, dynamic> data = jsonResponse['data'];
          debugPrint('🔓 [API] Response Data:');
          data.forEach((key, value) {
            debugPrint('    ✅ $key: $value');
          });
        }

        return jsonResponse;
      } else if (response.statusCode == 400) {
        debugPrint('❌ [API] Bad Request (400): আপনার পাঠানো ডাটা ফরম্যাট সঠিক নয়।');
        try {
          final errorBody = jsonDecode(response.body);
          debugPrint('❌ [API] Server Error Message: ${errorBody['message'] ?? errorBody}');
        } catch (_) {}
        return null;
      } else {
        debugPrint('❌ [API] Error: ${response.statusCode}');
        return null;
      }
    } on SocketException catch (e) {
      debugPrint('❌ [API] Network Error (No Internet): $e');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('❌ [API] Timeout Error: Request took too long. $e');
      return null;
    } catch (e) {
      debugPrint('❌ [API] Unknown Exception: $e');
      return null;
    }
  }

  // ৫-১০ মিনিট পর পর এই API দিয়ে লক স্ট্যাটাস চেক হবে
  Future<Map<String, dynamic>?> getLockStatus(String imei) async {
    debugPrint('-----------------------');
    debugPrint('🚀 [API] Sending GET Request to: $baseUrl/devices/$imei/lock-status');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/devices/$imei/lock-status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      debugPrint('📥 [API] Status Code: ${response.statusCode}');
      debugPrint('📥 [API] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('❌ [API] Error getting lock status: ${response.statusCode}');
        return null;
      }
    } on SocketException catch (e) {
      debugPrint('❌ [API] Network Error (No Internet): $e');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('❌ [API] Timeout Error: $e');
      return null;
    } catch (e) {
      debugPrint('❌ [API] Unknown Exception: $e');
      return null;
    }
  }
}