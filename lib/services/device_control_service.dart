import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceControlService {
  static const MethodChannel _channel =
  MethodChannel('com.example.devicelocunlock/controls');
  static const String KEY_DEVICE_LOCKED = 'device_locked';
  static const String KEY_DEVICE_ID = 'device_id';
  static const String KEY_ADMIN_ACTIVE = 'admin_active';

  Future<void> init() async {
    debugPrint('🔧 [DeviceControlService] Initializing...');
    await getDeviceId();
    await checkAdminStatus();
    debugPrint('✅ [DeviceControlService] Initialized');
  }

  // ─── Lock Device ───
  Future<bool> lockDevice() async {
    debugPrint('🔒 [DeviceControlService] lockDevice() called');
    try {
      final bool result = await _channel.invokeMethod('lockDevice');
      debugPrint('🔒 [DeviceControlService] lockDevice() result: $result');

      if (result) {
        await _saveDeviceLockStatus(true);
        debugPrint('✅ [DeviceControlService] Lock status saved: true');
      }
      return result;
    } on PlatformException catch (e) {
      debugPrint('❌ [DeviceControlService] PlatformException: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ [DeviceControlService] Error: $e');
      return false;
    }
  }

  // ─── Unlock Device ───
  Future<bool> unlockDevice() async {
    debugPrint('🔓 [DeviceControlService] unlockDevice() called');
    try {
      await _saveDeviceLockStatus(false);
      debugPrint('✅ [DeviceControlService] Unlock status saved: false');
      return true;
    } catch (e) {
      debugPrint('❌ [DeviceControlService] Error unlocking: $e');
      return false;
    }
  }

  // ─── Check if Device is Locked ───
  Future<bool> isDeviceLocked() async {
    debugPrint('🔍 [DeviceControlService] isDeviceLocked() called');
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isLocked = prefs.getBool(KEY_DEVICE_LOCKED) ?? false;
      debugPrint('📦 [DeviceControlService] isDeviceLocked: $isLocked');
      return isLocked;
    } catch (e) {
      debugPrint('❌ [DeviceControlService] Error checking lock: $e');
      return false;
    }
  }

  Future<void> _saveDeviceLockStatus(bool isLocked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_DEVICE_LOCKED, isLocked);
    } catch (e) {
      debugPrint('❌ Error saving lock status: $e');
    }
  }

  // ─── Get Device ID ───
  Future<String> getDeviceId() async {
    debugPrint('📱 [DeviceControlService] getDeviceId() called');
    try {
      final String deviceId = await _channel.invokeMethod('getDeviceId');
      debugPrint('📱 Device ID: $deviceId');
      await _saveDeviceId(deviceId);
      return deviceId;
    } on PlatformException catch (e) {
      debugPrint('❌ Error getting device ID: ${e.message}');
      return 'UNKNOWN_DEVICE';
    }
  }

  Future<void> _saveDeviceId(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(KEY_DEVICE_ID, deviceId);
    } catch (e) {
      debugPrint('❌ Error saving device ID: $e');
    }
  }

  // ─── Check Admin Status ───
  Future<bool> checkAdminStatus() async {
    debugPrint('🔐 [DeviceControlService] checkAdminStatus() called');
    try {
      final bool active = await _channel.invokeMethod('isAdminActive');
      debugPrint('🔐 Admin active: $active');
      await _saveAdminStatus(active);
      return active;
    } on PlatformException catch (e) {
      debugPrint('❌ Error checking admin: ${e.message}');
      return false;
    }
  }

  Future<void> _saveAdminStatus(bool active) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_ADMIN_ACTIVE, active);
    } catch (e) {
      debugPrint('❌ Error saving admin status: $e');
    }
  }

  // ─── Activate Admin ───
  Future<bool> activateAdmin() async {
    debugPrint('🔐 [DeviceControlService] activateAdmin() called');
    try {
      await _channel.invokeMethod('activateAdmin');
      debugPrint('⏳ Waiting for admin activation...');
      await Future.delayed(const Duration(seconds: 2));
      return await checkAdminStatus();
    } on PlatformException catch (e) {
      debugPrint('❌ Error activating admin: ${e.message}');
      return false;
    }
  }

  // ─── Block Uninstall ───
  Future<bool> blockUninstall({required bool block}) async {
    debugPrint('🚫 blockUninstall() called: $block');
    try {
      final result = await _channel.invokeMethod('blockUninstall', {
        'packageName': 'com.example.devicelocunlock',
        'block': block,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ Error blocking uninstall: ${e.message}');
      return false;
    }
  }
}