import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static late SharedPreferences _prefs;

  static const String KEY_DEVICE_ID = 'device_id';
  static const String KEY_FCM_TOKEN = 'fcm_token';
  static const String KEY_ADMIN_ACTIVE = 'admin_active';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setDeviceId(String deviceId) async {
    await _prefs.setString(KEY_DEVICE_ID, deviceId);
  }

  static String getDeviceId() {
    return _prefs.getString(KEY_DEVICE_ID) ?? '';
  }

  static Future<void> setFCMToken(String token) async {
    await _prefs.setString(KEY_FCM_TOKEN, token);
  }

  static String? getFCMToken() {
    return _prefs.getString(KEY_FCM_TOKEN);
  }

  static Future<void> setAdminActive(bool active) async {
    await _prefs.setBool(KEY_ADMIN_ACTIVE, active);
  }

  static bool isAdminActive() {
    return _prefs.getBool(KEY_ADMIN_ACTIVE) ?? false;
  }
}