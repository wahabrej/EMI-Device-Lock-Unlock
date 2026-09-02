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
  
  // Device Control Service initialization and start sync
  await DeviceControlService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ১. প্রয়োজনীয় স্ট্যাটাস চেক করা
    final bool isLocked = SharedPreferencesService.isDeviceLocked();
    final String imei = SharedPreferencesService.getIMEI();
    final bool isLoggedIn = imei.isNotEmpty;

    // ২. সরাসরি সঠিক স্ক্রিনটি নির্ধারণ করা
    Widget startScreen;
    if (isLocked) {
      startScreen = const LockScreen();
    } else if (isLoggedIn) {
      startScreen = const HomeScreen();
    } else {
      startScreen = const LoginScreen();
    }

    return ScreenUtilInit(
      minTextAdapt: true,
      splitScreenMode: true,
      designSize: const Size(375, 812),
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DeviceControlService()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            // 'home' প্রোপার্টি ব্যবহার করা হয়েছে যাতে স্ট্যাক পুরোপুরি ক্লিন থাকে
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
          ),
        );
      },
    );
  }
}
