import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'services/click_sound.dart';
import 'theme/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  ClickSound.instance.init();
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
      home: const _Root(),
    );
  }
}

/// Shows the boot [SplashScreen] first, then crossfades into the [HomeShell].
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _ready
          ? const HomeShell(key: ValueKey('home'))
          : SplashScreen(
              key: const ValueKey('splash'),
              onFinish: () => setState(() => _ready = true),
            ),
    );
  }
}
