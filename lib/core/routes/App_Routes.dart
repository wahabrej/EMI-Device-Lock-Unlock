import 'package:devicelocunlock/screens/home_screen.dart';
import 'package:devicelocunlock/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'Routes_name.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/': (context) => const LoginScreen(),

    RouteName.loginScreen: (context) => const LoginScreen(),
    RouteName.homeScreen: (context) => const HomeScreen(),

  };
}
