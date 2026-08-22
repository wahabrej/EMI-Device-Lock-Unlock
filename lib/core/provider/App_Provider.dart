import 'package:provider/provider.dart';

import '../../viewModel/LoginScreenProvider.dart';

class AppProviders {
  static List<ChangeNotifierProvider> getProviders() {
    return [
      ChangeNotifierProvider<LoginScreenProvider>(
        create: (context) => LoginScreenProvider(),
      ),

    ];
  }
}