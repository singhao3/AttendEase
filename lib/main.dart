import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:psm2_attendease/services/notification_service.dart';
import 'routing/app_router.dart';
import 'routing/routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/authentication_bloc.dart';
import 'bloc/attendance_bloc.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthenticationBloc>(
          create: (context) => AuthenticationBloc()..add(AppStarted()),
        ),
        BlocProvider<AttendanceBloc>(
          create: (context) => AttendanceBloc(''),
        ),
      ],
      child: const App(),
    );
  }
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  AppState createState() => AppState();
}

class AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          title: 'Login & Signup App',
          theme: ThemeData(
            useMaterial3: true,
          ),
          onGenerateRoute: AppRouter().generateRoute,
          debugShowCheckedModeBanner: false,
          home: BlocListener<AuthenticationBloc, AuthenticationState>(
            listener: (context, state) {
              Future.microtask(() {
                if (state is AuthenticationUnauthenticated) {
                  Navigator.pushReplacementNamed(context, Routes.loginScreen);
                } else if (state is AuthenticationAuthenticated) {
                  Navigator.pushReplacementNamed(context, Routes.homeScreen);
                } else if (state is AdminAuthenticated) {
                  Navigator.pushReplacementNamed(context, Routes.adminHomeScreen);
                }
              });
            },
            child: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        );
      },
    );
  }
}
