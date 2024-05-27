import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/routing/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3), () {});
    // ignore: use_build_context_synchronously
    Navigator.pushReplacementNamed(context, Routes.loginScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/images/splash.webp', 
              width: 300.w,  
              height: 300.h, 
            ),
            SizedBox(height: 20.h),
            Text('Welcome to Attendease', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 50, 87, 117))),
          ],
        ),
      ),
    );
  }
}
