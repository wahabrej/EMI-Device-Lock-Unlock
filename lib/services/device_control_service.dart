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
  DateTime? _lastManualActionTime;

  bool get isLocked => _isLocked;
  String get lockReason => _lockReason;

  Future<void> init() async {
    _isLocked = SharedPreferencesService.isDeviceLocked();
    _lockReason = SharedPreferencesService.getLockReason();
    debugPrint('🏁 [Service] Initialized. Current local status: $_isLocked');

    await getDeviceId();
    await checkAdminStatus();

    final imei = SharedPreferencesService.getIMEI();
    if (imei.isNotEmpty) {
      startLockStatusSync();
    }
  }

  void startLockStatusSync() {
    _syncTimer?.cancel();
    debugPrint('🔄 [Sync] Starting background sync...');
    syncWithServer();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await syncWithServer();
    });
  }

  void stopLockStatusSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> syncWithServer() async {
    final imei = SharedPreferencesService.getIMEI();
    if (imei.isEmpty) return;

    if (_lastManualActionTime != null && 
        DateTime.now().difference(_lastManualActionTime!).inSeconds < 60) {
      return;
    }

    try {
      final response = await _apiService.getLockStatus(imei);
      if (response != null && response['success'] == true) {
        final data = response['data'];
        if (data == null) return;

        final dynamic rawStatus = data['isLocked'] ?? data['is_locked'];
        bool serverLockStatus = false;
        if (rawStatus is bool) serverLockStatus = rawStatus;
        else if (rawStatus is int) serverLockStatus = rawStatus == 1;
        else if (rawStatus is String) serverLockStatus = rawStatus.toLowerCase() == 'true' || rawStatus == '1';

        if (serverLockStatus != _isLocked) {
          if (serverLockStatus) {
            debugPrint('🔒 [Sync] Server requested LOCK');
            await _executeLock();
          } else {
            debugPrint('🔓 [Sync] Server requested UNLOCK');
            await _executeUnlock();
          }
        }
        
        await SharedPreferencesService.saveLockData(data);
        _lockReason = data['lockReason']?.toString() ?? "";
      }
    } catch (e) {
      debugPrint('❌ [Sync] Error: $e');
    }
  }

  Future<bool> _executeLock() async {
    try {
      // ✅ ক্রাশের রিস্ক এড়াতে আগে স্ট্যাটাস সেভ করা হচ্ছে
      await SharedPreferencesService.setDeviceLocked(true);
      _isLocked = true;
      notifyListeners();

      await _controlsChannel.invokeMethod('lockDevice');
      debugPrint('✅ [Device] Locked via Service');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _executeUnlock() async {
    try {
      await SharedPreferencesService.setDeviceLocked(false);
      _isLocked = false;
      notifyListeners();

      await _controlsChannel.invokeMethod('unlockDevice');
      debugPrint('✅ [Device] Unlocked via Service');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> lockDevice() async {
    _lastManualActionTime = DateTime.now();
    return await _executeLock();
  }

  Future<bool> unlockDevice() async {
    _lastManualActionTime = DateTime.now();
    return await _executeUnlock();
  }

  Future<bool> isDeviceLocked() async => SharedPreferencesService.isDeviceLocked();

  Future<bool> checkAdminStatus() async {
    try {
      final bool active = await _controlsChannel.invokeMethod('isAdminActive');
      await SharedPreferencesService.setAdminActive(active);
      return active;
    } catch (_) { return false; }
  }

  Future<bool> activateAdmin() async {
    try {
      await _controlsChannel.invokeMethod('activateAdmin');
      await Future.delayed(const Duration(seconds: 1));
      return await checkAdminStatus();
    } catch (e) { return false; }
  }

  Future<String> getDeviceId() async {
    try {
      final String id = await _controlsChannel.invokeMethod('getDeviceId');
      await SharedPreferencesService.setDeviceId(id);
      return id;
    } catch (_) { return 'UNKNOWN'; }
  }

  Future<Map<String, dynamic>> getFullDeviceInfo() async {
    try {
      final dynamic info = await _deviceInfoChannel.invokeMethod('getDeviceInfo');
      return Map<String, dynamic>.from(info);
    } catch (e) {
      return {};
    }
  }
}
