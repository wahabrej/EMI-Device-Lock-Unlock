import 'package:devicelocunlock/core/routes/Routes_name.dart';
import 'package:devicelocunlock/services/device_control_service.dart';
import 'package:devicelocunlock/services/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    // ১. স্ট্যাটাস বার এবং নেভিগেশন বার পুরোপুরি লুকিয়ে ফেলা
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // ২. আনলক হওয়ার লিসেনার যুক্ত করা
    DeviceControlService.instance.addListener(_onServiceChange);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    DeviceControlService.instance.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (!DeviceControlService.instance.isLocked) {
      if (mounted) {
        // ✅ আনলক হওয়ার পর স্ট্যাক ক্লিয়ার করে সরাসরি হোম স্ক্রিনে যাবে
        Navigator.pushNamedAndRemoveUntil(
          context, 
          RouteName.homeScreen, 
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockReason = SharedPreferencesService.getLockReason();
    final customerName = SharedPreferencesService.getCustomerName();

    return PopScope(
      canPop: false, // ব্যাক বাটন অকেজো
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white,
                size: 100,
              ),
              const SizedBox(height: 30),
              const Text(
                'PHONE DISABLED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Text(
                      'User: $customerName',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      lockReason.isNotEmpty 
                          ? lockReason 
                          : 'This device has been locked by the administrator. Please pay your due to regain access.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              const Text(
                'Contact your administrator to unlock.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'WAITING FOR ADMIN UNLOCK...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
