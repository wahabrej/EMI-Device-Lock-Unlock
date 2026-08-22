import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../services/device_control_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAdminActive = false;
  bool _isDeviceLocked = false;
  bool _isLoading = false;
  bool _isLoadingInfo = true;
  String _errorMessage = '';

  String _deviceModel = 'Loading...';
  String _imeiNumber = 'Loading...';
  String _androidVersion = 'Loading...';
  String _batteryLevel = 'Loading...';
  String _storageUsed = 'Loading...';
  String _deviceStatus = 'Active';
  String _lockMessage = '';

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _getRealDeviceInfo();
    _checkDeviceStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final active = await DeviceControlService().checkAdminStatus();
      setState(() {
        _isAdminActive = active;
      });
      debugPrint('🔐 Admin active: $active');
    } catch (e) {
      debugPrint('❌ Error checking admin: $e');
    }
  }

  Future<void> _getRealDeviceInfo() async {
    setState(() {
      _isLoadingInfo = true;
      _errorMessage = '';
    });

    try {
      const platform = MethodChannel('com.example.smartpay/device');
      final dynamic result = await platform.invokeMethod('getDeviceInfo');

      Map<String, dynamic>? info;
      if (result is Map) {
        info = Map<String, dynamic>.from(result);
      }

      if (info != null && info.isNotEmpty) {
        setState(() {
          _deviceModel = info?['model']?.toString() ?? 'Unknown Model';
          _imeiNumber = info?['imei']?.toString() ?? 'Unknown IMEI';
          _androidVersion = info?['androidVersion']?.toString() ?? 'Unknown Version';
          _batteryLevel = info?['batteryLevel']?.toString() ?? 'N/A';
          _storageUsed = info?['storageUsed']?.toString() ?? 'N/A';
          _isLoadingInfo = false;
        });
      } else {
        await _getIndividualDeviceInfo();
      }
    } catch (e) {
      debugPrint('❌ Error getting device info: $e');
      await _getIndividualDeviceInfo();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInfo = false;
        });
      }
    }
  }

  Future<void> _getIndividualDeviceInfo() async {
    try {
      const platform = MethodChannel('com.example.smartpay/device');
      setState(() async {
        _deviceModel = await platform.invokeMethod('getDeviceModel');
        _imeiNumber = await platform.invokeMethod('getIMEI');
        _androidVersion = await platform.invokeMethod('getAndroidVersion');
        _batteryLevel = await platform.invokeMethod('getBatteryLevel');
        _storageUsed = await platform.invokeMethod('getStorageInfo');
      });
    } catch (e) {
      debugPrint('❌ Error getting individual info: $e');
      setState(() {
        _errorMessage = 'Error loading device info';
      });
    }
  }

  Future<void> _checkDeviceStatus() async {
    try {
      final isLocked = await DeviceControlService().isDeviceLocked();
      setState(() {
        _isDeviceLocked = isLocked;
        _deviceStatus = isLocked ? 'Locked' : 'Active';
      });
    } catch (e) {
      debugPrint('❌ Error checking status: $e');
    }
  }

  // ─── Activate Admin ───
  Future<void> _activateAdmin() async {
    debugPrint('🔐 [HomeScreen] _activateAdmin() called');
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await DeviceControlService().activateAdmin();
      debugPrint('🔐 [HomeScreen] Activate admin result: $result');

      setState(() {
        _isAdminActive = result;
      });

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Admin Activated Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to activate admin. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error activating admin: $e');
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _lockDevice() async {
    debugPrint('🔒 [HomeScreen] _lockDevice() called');
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await DeviceControlService().lockDevice();
      debugPrint('🔒 [HomeScreen] lockDevice result: $result');

      if (result) {
        setState(() {
          _isDeviceLocked = true;
          _deviceStatus = 'Locked';
          _lockMessage = '✅ Device locked successfully!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Device Locked Successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _showLockDialog();
      } else {
        setState(() {
          _errorMessage = '❌ Failed to lock device. Admin not active.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to lock device. Admin not active.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error locking device: $e');
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unlockDevice() async {
    debugPrint('🔓 [HomeScreen] _unlockDevice() called');
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await DeviceControlService().unlockDevice();
      debugPrint('🔓 [HomeScreen] unlockDevice result: $result');

      if (result) {
        setState(() {
          _isDeviceLocked = false;
          _deviceStatus = 'Active';
          _lockMessage = '✅ Device unlocked successfully!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔓 Device Unlocked Successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = '❌ Failed to unlock device.';
        });
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error unlocking device: $e');
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock, color: Colors.red),
            SizedBox(width: 8.w),
            const Text('Device Locked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
            SizedBox(height: 12.h),
            const Text(
              'This device has been locked!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8.h),
            const Text(
              'Please contact your administrator to unlock.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _unlockDevice();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unlock Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Device Management'),
        backgroundColor: const Color(0xFF1A6FB0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isAdminActive ? Icons.security : Icons.security_outlined),
            onPressed: _checkAdminStatus,
            tooltip: 'Admin Status',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _getRealDeviceInfo,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Admin Status Banner ───
              _buildAdminBanner(),

              SizedBox(height: 16.h),

              // ─── Error Message ───
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(12.w),
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 18.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12.sp),
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Device Info Card ───
              _buildDeviceInfoCard(),
              SizedBox(height: 16.h),

              // ─── Lock/Unlock Card ───
              _buildLockToggleCard(),
              SizedBox(height: 16.h),

              // ─── Quick Actions Card ───
              _buildQuickActionsCard(),

              if (_lockMessage.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 16.h),
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _lockMessage,
                            style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Admin Banner ───
  Widget _buildAdminBanner() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _isAdminActive ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: _isAdminActive ? Colors.green.shade300 : Colors.orange.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isAdminActive ? Icons.check_circle : Icons.warning_amber_rounded,
            color: _isAdminActive ? Colors.green : Colors.orange,
            size: 20.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              _isAdminActive
                  ? '✅ Device Admin is Active. You can lock/unlock device.'
                  : '⚠️ Device Admin is NOT Active. Click "Activate Admin" below.',
              style: TextStyle(
                color: _isAdminActive ? Colors.green.shade800 : Colors.orange.shade800,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!_isAdminActive)
            ElevatedButton(
              onPressed: _isLoading ? null : _activateAdmin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isLoading
                  ? SizedBox(
                width: 16.w,
                height: 16.h,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text('Activate'),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A6FB0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.phone_android, color: const Color(0xFF1A6FB0), size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Information',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                    ),
                    Text(
                      _isLoadingInfo ? 'Loading device info...' : 'Real device details',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              if (_isLoadingInfo)
                SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A6FB0)),
                ),
            ],
          ),
          Divider(height: 24.h, color: Colors.grey.shade200),
          Row(
            children: [
              Expanded(child: _buildInfoItem(Icons.smartphone, 'Model', _deviceModel, _isLoadingInfo)),
              Expanded(child: _buildInfoItem(Icons.numbers, 'IMEI', _imeiNumber, _isLoadingInfo)),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(child: _buildInfoItem(Icons.android, 'Android', _androidVersion, _isLoadingInfo)),
              Expanded(child: _buildInfoItem(Icons.battery_charging_full, 'Battery', _batteryLevel, _isLoadingInfo)),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(child: _buildInfoItem(Icons.storage, 'Storage', _storageUsed, _isLoadingInfo)),
              Expanded(child: _buildInfoItem(Icons.info_outline, 'Status', _deviceStatus, _isLoadingInfo)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, bool isLoading) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: Colors.grey.shade600),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              if (isLoading)
                SizedBox(width: 14.w, height: 14.h, child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A6FB0)))
              else
                Text(value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLockToggleCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_isDeviceLocked ? Icons.lock : Icons.lock_open, color: _isDeviceLocked ? Colors.red : Colors.green, size: 22.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device Control', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
                    Text(
                      _isDeviceLocked ? '🔒 Device is currently LOCKED' : '🔓 Device is currently UNLOCKED',
                      style: TextStyle(fontSize: 12.sp, color: _isDeviceLocked ? Colors.red : Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading || !_isAdminActive ? null : (_isDeviceLocked ? _unlockDevice : _lockDevice),
                  icon: _isLoading
                      ? SizedBox(height: 20.w, width: 20.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(_isDeviceLocked ? Icons.lock_open : Icons.lock, size: 18.sp),
                  label: Text(
                    _isDeviceLocked ? 'UNLOCK DEVICE' : 'LOCK DEVICE',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDeviceLocked ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          if (!_isAdminActive)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                '⚠️ Activate admin first to lock/unlock device',
                style: TextStyle(fontSize: 11.sp, color: Colors.orange.shade700),
              ),
            ),
          if (_isDeviceLocked)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Device is locked! Click UNLOCK to unlock.',
                        style: TextStyle(fontSize: 12.sp, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(child: _buildActionButton(Icons.refresh, 'Refresh Info', Colors.blue, _getRealDeviceInfo)),
              SizedBox(width: 12.w),
              Expanded(child: _buildActionButton(Icons.info_outline, 'Device Status', Colors.purple, _checkDeviceStatus)),
              SizedBox(width: 12.w),
              Expanded(child: _buildActionButton(Icons.admin_panel_settings, 'Admin', Colors.orange, _checkAdminStatus)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 4.h),
            Text(label, style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}