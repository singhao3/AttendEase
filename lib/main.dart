import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'routing/app_router.dart';
import 'routing/routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/authentication_bloc.dart';
import 'bloc/attendance_bloc.dart'; // Import AttendanceBloc
import 'firebase_options.dart';

late String initialRoute;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirebaseAuth.instance.authStateChanges().listen(
    (user) {
      if (user == null || !user.emailVerified) {
        initialRoute = Routes.splashScreen;
      } else {
        initialRoute = Routes.homeScreen;
      }
    },
  );

  final AuthenticationBloc authenticationBloc = AuthenticationBloc();
  final userId = FirebaseAuth.instance.currentUser?.uid ?? ''; // Get the current user ID
  final AttendanceBloc attendanceBloc = AttendanceBloc(userId)..add(LoadAttendance()); // Initialize AttendanceBloc

  await ScreenUtil.ensureScreenSize();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthenticationBloc>(
          create: (context) => authenticationBloc,
        ),
        BlocProvider<AttendanceBloc>(
          create: (context) => attendanceBloc,
        ),
      ],
      child: MyApp(router: AppRouter()),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppRouter router;

  const MyApp({super.key, required this.router});

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
          onGenerateRoute: router.generateRoute,
          debugShowCheckedModeBanner: false,
          initialRoute: initialRoute,
        );
      },
    );
  }
}
