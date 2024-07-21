import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:psm2_attendease/services/notification_service.dart';
import 'package:workmanager/workmanager.dart';
import 'routing/app_router.dart';
import 'routing/routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/authentication_bloc.dart';
import 'bloc/attendance_bloc.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _requestLocationPermission();

  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  Workmanager().registerPeriodicTask(
    "uniqueTaskId",
    "checkAttendanceStatus",
    frequency: const Duration(hours: 1),
  );

  runApp(const MyApp());
}

Future<void> _requestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }
  if (permission == LocationPermission.deniedForever) {
    return Future.error('Location permissions are permanently denied');
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Ensure Firebase is initialized
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Check network connectivity
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      return Future.value(false);
    }

    // Get Firestore instance
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Logic to mark students as absent for today
    await markTodayStudentsAbsent(firestore);

    return Future.value(true);
  });
}

Future<void> markTodayStudentsAbsent(FirebaseFirestore firestore) async {
  final now = DateTime.now();
  final weekId = "${now.year}-${weekOfYear(now)}";
  final users = await firestore.collection('users').get();

  final today = now.weekday.toString();

  for (var userDoc in users.docs) {
    var userData = userDoc.data();

    // Skip if the user is an admin
    if (userData['role'] == 'admin') {
      continue;
    }

    if (userData['weeklySchedule'] != null) {
      var weeklySchedule = userData['weeklySchedule'];
      if (weeklySchedule.containsKey(today) && weeklySchedule[today] is List) {
        for (var classInfo in weeklySchedule[today]) {
          var classEndTime = _parseClassTime(classInfo['endTime']);

          if (now.isAfter(classEndTime)) {
            var attendanceDoc = await firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('weeklyAttendance')
                .doc(weekId)
                .get();

            if (!attendanceDoc.exists ||
                !attendanceDoc.data()!.containsKey(today) ||
                !_hasMarkedAbsent(attendanceDoc.data()![today],
                    classInfo['subject'], classEndTime)) {
              await firestore
                  .collection('users')
                  .doc(userDoc.id)
                  .collection('weeklyAttendance')
                  .doc(weekId)
                  .set({
                today: FieldValue.arrayUnion([
                  {
                    'subject': classInfo['subject'],
                    'status': 'absent',
                    'timestamp': DateTime.now().toIso8601String(),
                    'classTime': classEndTime
                        .toIso8601String(), // Save the class end time to avoid duplicate checks
                  }
                ])
              }, SetOptions(merge: true));
            }
          }
        }
      }
    }
  }
}

bool _hasMarkedAbsent(List attendanceList, String subject, DateTime classTime) {
  for (var record in attendanceList) {
    if (record['subject'] == subject &&
        record['status'] == 'absent' &&
        DateTime.parse(record['classTime']) == classTime) {
      return true;
    }
  }
  return false;
}

int weekOfYear(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final dayOfYear = date.difference(firstDayOfYear).inDays + 1;

  // Get the ISO week number
  final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
  return weekNumber;
}

DateTime _parseClassTime(String time) {
  final now = DateTime.now();
  final timeParts = time.split(' ');

  if (timeParts.length != 2) {
    throw FormatException("Invalid time format: $time");
  }

  final period = timeParts[1];
  final hourMinuteParts = timeParts[0].split(':');

  if (hourMinuteParts.length != 2) {
    throw FormatException("Invalid time format: $time");
  }

  int hour = int.parse(hourMinuteParts[0]);
  final int minute = int.parse(hourMinuteParts[1]);

  if (period == 'PM' && hour != 12) {
    hour += 12;
  } else if (period == 'AM' && hour == 12) {
    hour = 0;
  }

  return DateTime(now.year, now.month, now.day, hour, minute);
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
                  Navigator.pushReplacementNamed(
                      context, Routes.adminHomeScreen);
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
