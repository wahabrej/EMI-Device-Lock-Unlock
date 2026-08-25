import 'dart:async';
import 'package:devicelocunlock/services/api_service.dart';
import 'package:devicelocunlock/services/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeviceControlService extends ChangeNotifier {
  static final DeviceControlService _instance = DeviceControlService._internal();
  static DeviceControlService get instance => _instance;
  DeviceControlService._internal();

  factory DeviceControlService() => _instance;

  static const MethodChannel _controlsChannel = MethodChannel('com.example.devicelocunlock/controls');
  static const MethodChannel _deviceInfoChannel = MethodChannel('com.example.devicelocunlock/device');

  Timer? _syncTimer;
  final ApiService _apiService = ApiService();

  bool _isLocked = false;
  String _lockReason = "";

  bool get isLocked => _isLocked;
  String get lockReason => _lockReason;

  Future<void> init() async {
    _isLocked = SharedPreferencesService.isDeviceLocked();
    _lockReason = SharedPreferencesService.getLockReason();

    await getDeviceId();
    await checkAdminStatus();

    final imei = SharedPreferencesService.getIMEI();
    if (imei.isNotEmpty) {
      startLockStatusSync();
    }
  }

  void startLockStatusSync() {
    _syncTimer?.cancel();

    // ক্লায়েন্টের রিকোয়ারমেন্ট: ৫ মিনিট পরে চেক (বা ১০ মিনিট)
    debugPrint('🔄 [Sync] Timer শুরু হলো (৫ মিনিট পরপর)');
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await syncWithServer();
    });

    // প্রথমবার চেক করা হবে
    syncWithServer();
  }

  Future<void> syncWithServer() async {
    final imei = SharedPreferencesService.getIMEI();
    if (imei.isEmpty) return;

    debugPrint('🔍 [Sync] Lock Status চেক করা হচ্ছে (IMEI: $imei)');
    final response = await _apiService.getLockStatus(imei);

    if (response != null && response['success'] == true) {
      final data = response['data'];
      final bool serverLockStatus = data['isLocked'] ?? false;

      await SharedPreferencesService.saveLockData(data);
      _lockReason = data['lockReason'] ?? "";

      if (serverLockStatus) {
        debugPrint('🔒 [Sync] Backend থেকে LOCKED স্ট্যাটাস এসেছে!');
        await lockDevice();
      } else {
        debugPrint('🔓 [Sync] Backend থেকে UNLOCKED স্ট্যাটাস এসেছে!');
        await unlockDevice();
      }
    } else {
      debugPrint('❌ [Sync] API কল failed বা সঠিক রেসপন্স আসেনি');
    }
  }

  void stopLockStatusSync() {
    _syncTimer?.cancel();
  }

  Future<bool> lockDevice() async {
    try {
      debugPrint('🔒 [Control] Device লক করা হচ্ছে...');
      final bool result = await _controlsChannel.invokeMethod('lockDevice');
      _isLocked = true;
      await SharedPreferencesService.setDeviceLocked(true);
      notifyListeners(); // UI update
      debugPrint('✅ [Control] Device লক হয়েছে!');
      return result;
    } on PlatformException catch (e) {
      debugPrint('❌ [Control] লক করতে ব্যর্থ: ${e.message}');
      return false;
    }
  }

  Future<bool> unlockDevice() async {
    debugPrint('🔓 [Control] Device আনলক করা হচ্ছে...');
    try {
      await _controlsChannel.invokeMethod('unlockDevice');
    } catch (e) {}

    _isLocked = false;
    await SharedPreferencesService.setDeviceLocked(false);
    notifyListeners(); // UI update
    debugPrint('✅ [Control] Device আনলক হয়েছে!');
    return true;
  }

  Future<bool> isDeviceLocked() async {
    _isLocked = SharedPreferencesService.isDeviceLocked();
    return _isLocked;
  }

  // গুরুত্বপূর্ণ: API তে পাঠানোর জন্য সব ডিভাইস ইনফো
  Future<Map<String, dynamic>> getFullDeviceInfo() async {
    try {
      final Map<dynamic, dynamic>? info = await _deviceInfoChannel.invokeMethod('getDeviceInfo');
      return Map<String, dynamic>.from(info ?? {});
    } catch (e) {
      return {};
    }
  }

  Future<String> getDeviceId() async {
    try {
      final String deviceId = await _controlsChannel.invokeMethod('getDeviceId');
      await SharedPreferencesService.setDeviceId(deviceId);
      return deviceId;
    } catch (_) {
      return 'UNKNOWN';
    }
  }

  Future<bool> checkAdminStatus() async {
    try {
      final bool active = await _controlsChannel.invokeMethod('isAdminActive');
      await SharedPreferencesService.setAdminActive(active);
      return active;
    } catch (_) {
      return false;
    }
  }

  Future<bool> activateAdmin() async {
    try {
      await _controlsChannel.invokeMethod('activateAdmin');
      await Future.delayed(const Duration(seconds: 1));
      return await checkAdminStatus();
    } catch (e) {
      return false;
    }
  }
}