import 'package:flutter/material.dart';
import 'package:songhut/constants.dart';
import 'package:songhut/screens/homepage/home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate as soon as the first frame is painted instead of forcing a
    // hardcoded 1s delay — faster perceived startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MyHomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor,
      body: Center(
        child: Image.asset('lib/assets/AudioMarkSplashScreen.png'),
      ),
    );
  }
}
