import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';
import 'theme/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const HomePanelApp());
}

class HomePanelApp extends StatelessWidget {
  const HomePanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgBottom,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.blue,
          surface: AppColors.bgBottom,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
