import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:songhut/provider/songModelProvider.dart';
import 'package:songhut/screens/splash_screen.dart';
import 'package:songhut/services/prefs_service.dart';
import 'package:songhut/theme/app_theme.dart';

/// Central crash hook. Every uncaught Flutter, platform and async error funnels
/// here so nothing fails silently. Drop in Sentry/Crashlytics at this one spot
/// (e.g. `Sentry.captureException(error, stackTrace: stack)`) to enable remote
/// crash reporting — no other call sites need to change.
void reportError(Object error, StackTrace? stack) {
  debugPrint('AudioMark uncaught error: $error\n$stack');
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Route framework + platform errors through the single crash hook.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      reportError(details.exception, details.stack);
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      reportError(error, stack);
      return true;
    };

    await PrefsService.instance.init();
    // Draw behind the status/navigation bars for a seamless, edge-to-edge feel.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    runApp(ChangeNotifierProvider(
      create: (context) => SongModelProvider(),
      child: const MyApp(),
    ));
  }, reportError);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AudioMark',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
