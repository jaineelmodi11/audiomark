import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:songhut/provider/songModelProvider.dart';
import 'package:songhut/screens/splash_screen.dart';
import 'package:songhut/theme/app_theme.dart';

void main() {
  runApp(ChangeNotifierProvider(
    create: (context) => SongModelProvider(),
    child: const MyApp(),
  ));
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
