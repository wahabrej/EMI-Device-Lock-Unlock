import 'package:devicelocunlock/core/routes/Routes_name.dart';
import 'package:devicelocunlock/screens/home_screen.dart';
import 'package:devicelocunlock/screens/lock_screen.dart';
import 'package:devicelocunlock/screens/login_screen.dart';
import 'package:devicelocunlock/services/device_control_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/routes/App_Routes.dart';
import 'services/shared_preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // SharedPreferences initialization
  await SharedPreferencesService.init();
  
  // Device Control Service initialization (Singleton instance)
  await DeviceControlService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Singleton instance ব্যবহার করা হচ্ছে যাতে সব স্টেট সিঙ্ক থাকে
        ChangeNotifierProvider.value(value: DeviceControlService.instance),
      ],
      child: ScreenUtilInit(
        minTextAdapt: true,
        splitScreenMode: true,
        designSize: const Size(375, 812),
        builder: (context, child) {
          return Consumer<DeviceControlService>(
            builder: (context, service, _) {
              // ১. প্রয়োজনীয় স্ট্যাটাস চেক করা
              final String imei = SharedPreferencesService.getIMEI();
              final bool isLoggedIn = imei.isNotEmpty;
              final bool isLocked = service.isLocked;

              // ২. সরাসরি সঠিক স্ক্রিনটি নির্ধারণ করা (রিয়েল-টাইম আপডেট হবে)
              // একবার লগইন হলে (imei থাকলে) সে আর কখনো LoginScreen দেখবে না
              Widget startScreen;
              if (isLocked) {
                startScreen = const LockScreen();
              } else if (isLoggedIn) {
                startScreen = const HomeScreen();
              } else {
                startScreen = const LoginScreen();
              }

              return MaterialApp(
                key: ValueKey("$isLocked-$isLoggedIn"), // স্ট্যাটাস চেঞ্জ হলে UI রিফ্রেশ নিশ্চিত করতে
                debugShowCheckedModeBanner: false,
                home: startScreen,
                routes: AppRoutes.routes,
                onUnknownRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Navigation Error'),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                                context, 
                                isLoggedIn ? RouteName.homeScreen : RouteName.loginScreen,
                                (route) => false
                              ),
                              child: const Text('Back to App'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                navigatorObservers: [HeroController()],
              );
            },
          );
        },
      ),
    );
  }
}
