import 'package:flutter/material.dart';

import '../services/device_control_service.dart';
import '../services/shared_preferences_service.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({super.key});

  @override
  State<DeviceRegistrationScreen> createState() => _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  String _deviceId = '';
  String? _fcmToken;
  bool _isRegistered = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    setState(() => _isLoading = true);

    _deviceId = SharedPreferencesService.getDeviceId();
    _fcmToken = SharedPreferencesService.getFCMToken();
    _isRegistered = _deviceId.isNotEmpty && _fcmToken != null;

    setState(() => _isLoading = false);
  }

  Future<void> _registerDevice() async {
    setState(() => _isLoading = true);

    try {
      // ডিভাইস আইডি সংগ্রহ করুন
      final deviceId = await DeviceControlService().getDeviceId();
      await SharedPreferencesService.setDeviceId(deviceId);

      // FCM টোকেন ইতিমধ্যে সংরক্ষিত আছে
      _fcmToken = SharedPreferencesService.getFCMToken();

      setState(() {
        _deviceId = deviceId;
        _isRegistered = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Device Registered Successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Registration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Registration'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Device ID', _deviceId),
                    const SizedBox(height: 8),
                    _buildInfoRow('FCM Token', _fcmToken ?? 'Not available'),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Registration Status',
                      _isRegistered ? '✅ Registered' : '❌ Not Registered',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!_isRegistered)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Register Device',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Device is already registered!',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Text(
              '⚠️ Note: Device registration is required for remote lock/unlock functionality.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}