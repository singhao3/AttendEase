import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import '/bloc/authentication_bloc.dart';
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
    _checkAuthentication();
  }

  void _checkAuthentication() {
    context.read<AuthenticationBloc>().add(AppStarted());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: BlocListener<AuthenticationBloc, AuthenticationState>(
          listener: (context, state) {
            if (state is AuthenticationAuthenticated) {
              Navigator.pushReplacementNamed(context, Routes.homeScreen);
            } else if (state is AuthenticationUnauthenticated) {
              Navigator.pushReplacementNamed(context, Routes.loginScreen);
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Lottie.network(
                'https://lottie.host/52a8fb3e-3ac8-4f14-a682-f26e5ef79424/X8rDMkQ12x.json',
                width: 200,
                height: 200,
              ),
              SizedBox(height: 20.h),
              Text('Welcome to Attendease',
                  style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 50, 87, 117))),
            ],
          ),
        ),
      ),
    );
  }
}
