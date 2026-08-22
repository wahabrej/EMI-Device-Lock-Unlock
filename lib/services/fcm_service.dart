import 'package:devicelocunlock/services/shared_preferences_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FCMService {
  FirebaseMessaging? _fcm;
  String? _fcmToken;

  Future<void> init() async {
    try {
      // Check if Firebase is initialized before accessing the instance
      if (Firebase.apps.isEmpty) return;
      
      _fcm = FirebaseMessaging.instance;
      
      NotificationSettings settings = await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _fcmToken = await _fcm!.getToken();
        if (_fcmToken != null) {
          await SharedPreferencesService.setFCMToken(_fcmToken!);
        }

        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

        _fcm!.onTokenRefresh.listen((token) {
          _fcmToken = token;
          SharedPreferencesService.setFCMToken(token);
        });
      }
    } catch (e) {
      debugPrint("FCM Initialization error: $e");
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      _handleCommand(message.data);
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    // Note: SharedPreferences might not be available here depending on setup
  }

  void _handleCommand(Map<String, dynamic> data) {
    final command = data['command'];
    switch (command) {
      case 'LOCK':
        break;
      case 'UNLOCK':
        break;
      default:
        break;
    }
  }

  Future<String?> getFCMToken() async {
    return _fcmToken;
  }
}
