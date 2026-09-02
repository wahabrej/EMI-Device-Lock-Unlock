import 'package:devicelocunlock/core/routes/Routes_name.dart';
import 'package:devicelocunlock/services/api_service.dart';
import 'package:devicelocunlock/services/device_control_service.dart';
import 'package:devicelocunlock/services/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _imei1Controller = TextEditingController();
  final TextEditingController _imei2Controller = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(); // 🆕 Added

  final FocusNode _imei1FocusNode = FocusNode();
  final FocusNode _imei2FocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode(); // 🆕 Added

  bool _isLoading = false;
  String? _errorMessage;
  bool _isImeiLoading = false;

  // Auto-detected device details (hidden in UI)
  Map<String, dynamic> _deviceInfo = {};

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchDeviceInfo();
  }

  @override
  void dispose() {
    _imei1Controller.dispose();
    _imei2Controller.dispose();
    _phoneController.dispose(); // 🆕 Added
    _imei1FocusNode.dispose();
    _imei2FocusNode.dispose();
    _phoneFocusNode.dispose(); // 🆕 Added
    super.dispose();
  }

  Future<void> _fetchDeviceInfo() async {
    setState(() {
      _isImeiLoading = true;
    });

    try {
      _deviceInfo = await DeviceControlService.instance.getFullDeviceInfo();
      debugPrint('✅ [LOGIN] Device Info fetched successfully: $_deviceInfo');
    } catch (e) {
      debugPrint('❌ [LOGIN] Error getting device details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isImeiLoading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String inputImei1 = _imei1Controller.text.trim();
      final String inputImei2 = _imei2Controller.text.trim();
      final String inputPhone = _phoneController.text.trim(); // 🆕 Added
      final String? fcmToken = SharedPreferencesService.getFCMToken();

      debugPrint('-----------------------');
      debugPrint('🔐 [LOGIN] Attempting to Login...');
      debugPrint('📱 [LOGIN] User Input IMEI 1: $inputImei1');
      debugPrint('📱 [LOGIN] User Input IMEI 2: $inputImei2');
      debugPrint('📞 [LOGIN] Customer Phone: $inputPhone'); // 🆕 Added
      debugPrint('-----------------------');

      final trackData = {
        "imei": inputImei1,
        "imei2": inputImei2,
        "customerPhone": inputPhone, // 🆕 Added
        "serialNumber": _deviceInfo['serialNumber'] ?? "",
        "batteryLevel": int.tryParse(_deviceInfo['batteryLevel']?.toString().replaceAll('%', '') ?? '85') ?? 85,
        "brand": _deviceInfo['brand'] ?? "Unknown",
        "model": _deviceInfo['model'] ?? "Unknown",
        "osVersion": _deviceInfo['osVersion'] ?? _deviceInfo['androidVersion'] ?? "Unknown",
        "appVersion": "1.0.0",
        "fcmToken": fcmToken ?? "NO_TOKEN"
      };

      debugPrint('📦 [LOGIN] Sending Tracking Data to API: $trackData');
      final response = await _apiService.trackDevice(trackData);

      if (response != null && response['success'] == true) {
        final data = response['data'];
        final bool isLocked = data['isLocked'] ?? false;

        debugPrint('-----------------------');
        debugPrint('🎉 [LOGIN] Login Successful!');
        debugPrint('🔒 [LOGIN] isLocked: $isLocked');
        debugPrint('📝 [LOGIN] lockReason: ${data['lockReason']}');
        debugPrint('👤 [LOGIN] customerName: ${data['customerName']}');
        debugPrint('📞 [LOGIN] customerPhone: ${data['customerPhone']}'); // 🆕 Added
        debugPrint('-----------------------');

        await SharedPreferencesService.setIMEI(inputImei1);
        await SharedPreferencesService.saveLockData(data);

        if (isLocked) {
          debugPrint('🔒 [LOGIN] Device is LOCKED from server. Locking device...');
          await DeviceControlService.instance.lockDevice();
          setState(() {
            _errorMessage = 'Device is Locked: ${data['lockReason'] ?? 'Unknown Reason'}';
          });
        } else {
          debugPrint('🔓 [LOGIN] Device is UNLOCKED. Proceeding to Home...');
          await DeviceControlService.instance.unlockDevice();
          DeviceControlService.instance.startLockStatusSync();
          if (mounted) {
            Navigator.pushReplacementNamed(context, RouteName.homeScreen);
          }
        }
      } else {
        debugPrint('❌ [LOGIN] API Failed or returned null.');
        setState(() {
          _errorMessage = 'Connection failed. Check your IMEI and Network.';
        });
      }
    } catch (e) {
      debugPrint('❌ [LOGIN] Exception caught: $e');
      setState(() {
        _errorMessage = 'Login error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF051B36), Color(0xFF051B36), Color(0xFF051B36)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _buildLogo(),
                    const SizedBox(height: 40),
                    _buildLoginCard(),
                    const SizedBox(height: 30),
                    _buildFooter(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Image.asset("assets/icons/logo.png", color: Colors.white),
        const SizedBox(height: 6),
        const Text(
          'Mobile Lock/Unlock ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Management System',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildIMEIField(
            controller: _imei1Controller,
            focusNode: _imei1FocusNode,
            label: 'IMEI 1 (Primary)',
            hint: 'Enter IMEI 1 (Dial *#06#)',
            onFieldSubmitted: (_) => _imei2FocusNode.requestFocus(),
          ),
          const SizedBox(height: 16),
          _buildIMEIField(
            controller: _imei2Controller,
            focusNode: _imei2FocusNode,
            label: 'IMEI 2 (Secondary)',
            hint: 'Enter IMEI 2 (Dial *#06#)',
            onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(), // 🆕 Changed
          ),
          const SizedBox(height: 16), // 🆕 Added spacing
          _buildPhoneField(), // 🆕 Added
          const SizedBox(height: 24),
          _buildLoginButton(),
          const SizedBox(height: 12),
          _buildDeviceInfo(),
        ],
      ),
    );
  }

  // 🆕 Phone Field Widget
  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Phone Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          focusNode: _phoneFocusNode,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11), // বাংলাদেশের মোবাইল নম্বরের জন্য
          ],
          decoration: InputDecoration(
            hintText: 'Enter Customer Phone Number (e.g., 017XXXXXXXX)',
            prefixIcon: const Icon(Icons.phone, color: Color(0xFF1A6FB0), size: 22),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter customer phone number';
            }
            if (value.length < 11) {
              return 'Phone number must be at least 11 digits';
            }
            if (value.length > 11) {
              return 'Phone number must be exactly 11 digits';
            }
            if (int.tryParse(value) == null) {
              return 'Phone number must be numeric';
            }
            return null;
          },
          onFieldSubmitted: (_) => _login(),
        ),
      ],
    );
  }

  Widget _buildIMEIField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required void Function(String) onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF1A6FB0), size: 22),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter IMEI';
            if (value.length != 15) return 'IMEI must be exactly 15 digits';
            if (int.tryParse(value) == null) return 'IMEI must be numeric';
            return null;
          },
          onFieldSubmitted: onFieldSubmitted,
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A6FB0),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isLoading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white)),
      ),
    );
  }

  Widget _buildDeviceInfo() {
    String serial = _deviceInfo['serialNumber'] ?? 'N/A';
    String imei2 = _deviceInfo['imei2'] ?? 'N/A';
    String brand = _deviceInfo['brand'] ?? 'N/A';
    String model = _deviceInfo['model'] ?? 'N/A';
    String os = _deviceInfo['osVersion'] ?? _deviceInfo['androidVersion'] ?? 'N/A';
    String battery = _deviceInfo['batteryLevel'] ?? 'N/A';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device Info (Auto-Detected)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 6),
          _buildInfoRow('serialNumber', serial),
          _buildInfoRow('imei2', imei2),
          _buildInfoRow('brand', brand),
          _buildInfoRow('model', model),
          _buildInfoRow('osVersion', os),
          _buildInfoRow('batteryLevel', battery),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Column(
      children: [
        Text('© 2024 SmartPay. All rights reserved.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}