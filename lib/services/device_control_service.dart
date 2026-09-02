import 'dart:async';
import 'package:devicelocunlock/services/api_service.dart';
import 'package:devicelocunlock/services/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeviceControlService extends ChangeNotifier {
  static final DeviceControlService _instance =
  DeviceControlService._internal();
  static DeviceControlService get instance => _instance;
  DeviceControlService._internal();

  factory DeviceControlService() => _instance;

  static const MethodChannel _controlsChannel = MethodChannel(
    'com.example.devicelocunlock/controls',
  );
  static const MethodChannel _deviceInfoChannel = MethodChannel(
    'com.example.devicelocunlock/device',
  );

  Timer? _syncTimer;
  final ApiService _apiService = ApiService();

  bool _isLocked = false;
  String _lockReason = "";

  bool get isLocked => _isLocked;
  String get lockReason => _lockReason;

  @override
  void dispose() {
    stopLockStatusSync();
    super.dispose();
  }

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

    debugPrint('🔄 [Sync] Timer শুরু হচ্ছে...');
    debugPrint('⏱️ [Sync] প্রথম চেক ১০ সেকেন্ড পর, তারপর প্রতি ১০ সেকেন্ড পরপর');

    // প্রথম চেক ১০ সেকেন্ড পর
    Future.delayed(const Duration(seconds: 5), () {
      syncWithServer();
    });

    // তারপর প্রতি ১০ সেকেন্ড পর পর চেক
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      debugPrint('⏰ [Sync] ১০ সেকেন্ড পার হয়েছে, চেক করা হচ্ছে...');
      await syncWithServer();
    });
  }

  //  নতুন মেথড - সরাসরি চেক শুরু করার জন্য
  Future<void> startSyncImmediately() async {
    _syncTimer?.cancel();
    debugPrint('🔄 [Sync] সাথে সাথেই চেক শুরু করা হচ্ছে...');
    await syncWithServer();

    // প্রতি ১০ সেকেন্ড পর পর চেক
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      debugPrint('⏰ [Sync] ১০ সেকেন্ড পার হয়েছে, চেক করা হচ্ছে...');
      await syncWithServer();
    });
  }

  void stopLockStatusSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('⏹️ [Sync] Timer বন্ধ করা হয়েছে');
  }

  // ম্যানুয়ালি চেক করার জন্য
  Future<void> manualSync() async {
    debugPrint('🔄 [Sync] ম্যানুয়ালি চেক করা হচ্ছে...');
    await syncWithServer();
  }

  Future<void> syncWithServer() async {
    final imei = SharedPreferencesService.getIMEI();
    if (imei.isEmpty) {
      debugPrint('⚠️ [Sync] IMEI পাওয়া যায়নি, চেক বাদ দেওয়া হচ্ছে');
      return;
    }

    debugPrint('🔍 [Sync] Lock Status চেক করা হচ্ছে (IMEI: $imei)');
    final response = await _apiService.getLockStatus(imei);

    if (response != null && response['success'] == true) {
      final data = response['data'];
      final bool serverLockStatus = data['isLocked'] ?? false;
      final String serverLockReason = data['lockReason'] ?? "";

      debugPrint('📊 [Sync] Server Response: isLocked=$serverLockStatus, reason=$serverLockReason');

      // SharedPreferences এ সেভ করা
      await SharedPreferencesService.saveLockData(data);
      _lockReason = serverLockReason;

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
    } catch (e) {
      debugPrint('⚠️ [Control] আনলক করতে সমস্যা: $e');
    }

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
      final Map<dynamic, dynamic>? info = await _deviceInfoChannel.invokeMethod(
        'getDeviceInfo',
      );
      return Map<String, dynamic>.from(info ?? {});
    } catch (e) {
      debugPrint('❌ [Device] ডিভাইস ইনফো পেতে ব্যর্থ: $e');
      return {};
    }
  }

  Future<String> getDeviceId() async {
    try {
      final String deviceId = await _controlsChannel.invokeMethod(
        'getDeviceId',
      );
      await SharedPreferencesService.setDeviceId(deviceId);
      debugPrint('📱 [Device] Device ID: $deviceId');
      return deviceId;
    } catch (_) {
      debugPrint('⚠️ [Device] Device ID পেতে ব্যর্থ');
      return 'UNKNOWN';
    }
  }

  Future<bool> checkAdminStatus() async {
    try {
      final bool active = await _controlsChannel.invokeMethod('isAdminActive');
      await SharedPreferencesService.setAdminActive(active);
      debugPrint('👑 [Admin] Admin Status: $active');
      return active;
    } catch (_) {
      debugPrint('⚠️ [Admin] Admin Status চেক করতে ব্যর্থ');
      return false;
    }
  }

  Future<bool> activateAdmin() async {
    try {
      debugPrint('👑 [Admin] Admin Activate করা হচ্ছে...');
      await _controlsChannel.invokeMethod('activateAdmin');
      await Future.delayed(const Duration(seconds: 1));
      final bool isActive = await checkAdminStatus();
      debugPrint('👑 [Admin] Admin Status: $isActive');
      return isActive;
    } catch (e) {
      debugPrint('❌ [Admin] Admin Activate করতে ব্যর্থ: $e');
      return false;
    }
  }
}