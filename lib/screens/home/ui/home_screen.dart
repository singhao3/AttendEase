import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_offline/flutter_offline.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../bloc/attendance_bloc.dart';
import '../../../core/widgets/no_internet.dart';
import '../../../core/widgets/user_header.dart';
import '../../../core/widgets/user_profile_section.dart';
import '../../../core/widgets/sign_out.dart';
import '../../../theming/colors.dart';
import '../../report/generate_report_screen.dart';
import '/theming/styles.dart';
import '/helpers/firebase_helpers.dart';
import '../../weekly_schedule/weekly_schedule_screen.dart';
import '../../attendance_history/attendance_history_screen.dart';
import '../../settings/settings_screen.dart';
import '../../../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? profileImageUrl;
  final FirebaseHelpers firebaseHelpers = FirebaseHelpers();

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && user.uid.isNotEmpty) {
        context.read<AttendanceBloc>().add(UpdateUserId(user.uid));
      }
    });
    if (context.read<AttendanceBloc>().state is! AttendanceLoaded) {
      context.read<AttendanceBloc>().add(LoadAttendance());
    }
  }

  Future<void> fetchUserProfile() async {
    profileImageUrl = await firebaseHelpers.fetchUserProfileUrl();
    if (mounted) setState(() {});
  }

  Future<void> _refreshAttendance() async {
    context.read<AttendanceBloc>().add(LoadAttendance());
  }

  String getToday() {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[now.weekday - 1];
  }

  bool isWeekend() {
    final today = getToday();
    return today == 'Saturday' || today == 'Sunday';
  }

  Future<void> _scanFace(BuildContext context, String subject, String day) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      context.read<AttendanceBloc>().add(ScanFaceForAttendance(image.path, subject, day));
    }
  }

  void _showDialog(BuildContext context, String title, String description, DialogType dialogType) {
    AwesomeDialog(
      context: context,
      dialogType: dialogType,
      animType: AnimType.rightSlide,
      title: title,
      desc: description,
      btnOkOnPress: () {
        context.read<AttendanceBloc>().add(ClearAttendance());
        context.read<AttendanceBloc>().add(LoadAttendance());
      },
    ).show();
  }

  Future<void> _launchLocation(String location) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = getToday();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorsManager.lightShadeOfGray,
        title: Text('AttendEase',
            style: GoogleFonts.ropaSans(
                textStyle: TextStyles.font24Blue700Weight)),
        centerTitle: true,
      ),
      drawer: _buildDrawer(context),
      body: OfflineBuilder(
        connectivityBuilder: (
          BuildContext context,
          ConnectivityResult connectivity,
          Widget child,
        ) {
          final bool connected = connectivity != ConnectivityResult.none;
          return connected
              ? BlocConsumer<AttendanceBloc, AttendanceState>(
                  listener: (context, state) {
                    if (state is AttendanceError) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(state.message)));
                    } else if (state is FaceScanFailed) {
                      _showDialog(context, 'Face Scan Failed', state.message,
                          DialogType.error);
                    } else if (state is FaceScanSuccess) {
                      _showDialog(context, 'Attendance Marked', state.message,
                          DialogType.success);
                    }
                  },
                  builder: (context, state) {
                    if (state is AttendanceInitial ||
                        state is FaceScanInProgress) {
                      return _buildLoadingIndicator();
                    } else if (state is AttendanceLoaded) {
                      // Ensure notifications are scheduled
                      _scheduleClassNotifications(state.weeklySchedule);
                      return _buildRefreshableHomePage(context, today,
                          state.weeklySchedule, state.weeklyAttendance);
                    } else if (state is AttendanceError) {
                      return _buildErrorState(state.message);
                    } else {
                      return _buildLoadingIndicator();
                    }
                  },
                )
              : const BuildNoInternet();
        },
        child: _buildLoadingIndicator(),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        color: ColorsManager.mainBlue,
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: GoogleFonts.ropaSans(
              textStyle: TextStyle(
                fontSize: 16.sp,
                color: Colors.red,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: () {
              context.read<AttendanceBloc>().add(LoadAttendance());
            },
            child: Text('Retry', style: GoogleFonts.ropaSans()),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekendMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            'https://lottie.host/11cc3045-6673-4699-9e9e-b6bec6ec994d/dSGyGiTKgS.json',
            width: 200,
            height: 200,
          ),
          SizedBox(height: 20.h),
          Text(
            'No classes today! Enjoy your weekend!',
            style: GoogleFonts.ropaSans(
              textStyle: TextStyle(
                fontSize: 20.sp,
                color: ColorsManager.mainBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const UserHeader(backgroundColor: ColorsManager.mainBlue,),
          _buildDrawerItem(
            title: 'Home',
            onTap: () => Navigator.of(context).pop(),
          ),
          _buildDrawerItem(
            title: 'Weekly Schedule',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeeklyScheduleScreen(
                    attendanceBloc: BlocProvider.of<AttendanceBloc>(context),
                  ),
                ),
              );
            },
          ),
          _buildDrawerItem(
            title: 'Attendance History',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttendanceHistoryScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            title: 'Generate Reports',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GenerateReportScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            title: 'Settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            title: 'Sign Out',
            onTap: () => SignOut.signOut(context),
          ),
          _buildDrawerItem(
            title: 'Trigger Test Notification',
            onTap: () async {
              await NotificationService.triggerTestNotification();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Test notification triggered.'),
              ));
            },
          ),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem({required String title, required VoidCallback onTap}) {
    return ListTile(
      title: Text(title, style: GoogleFonts.ropaSans()),
      onTap: onTap,
    );
  }

  Widget _buildRefreshableHomePage(BuildContext context, String today, Map<String, dynamic> weeklySchedule, Map<String, dynamic> weeklyAttendance) {
    return RefreshIndicator(
      onRefresh: _refreshAttendance,
      child: _homePage(context, today, weeklySchedule, weeklyAttendance),
    );
  }

  SafeArea _homePage(BuildContext context, String today, Map<String, dynamic> weeklySchedule, Map<String, dynamic> weeklyAttendance) {
    final userName = FirebaseAuth.instance.currentUser!.displayName ?? 'John';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15.w),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserProfileSection(profileImageUrl: profileImageUrl),
              SizedBox(height: 20.h),
              _welcomeText(userName),
              SizedBox(height: 20.h),
              isWeekend()
                  ? _buildWeekendMessage()
                  : _todayClassList(context, today, weeklySchedule[today] ?? [],
                      weeklyAttendance[today] ?? []),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcomeText(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Hi, $userName.',
            style: GoogleFonts.ropaSans(
              textStyle: TextStyle(
                fontSize: 32.sp,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Welcome to your Class',
            style: GoogleFonts.ropaSans(
              textStyle: TextStyle(
                fontSize: 24.sp,
                color: Colors.blue[300],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color generateAvatarColor(String subject) {
    final random = Random(subject.hashCode);
    final hue = random.nextDouble() * 360;
    return HSVColor.fromAHSV(1.0, hue, 0.8, 0.8).toColor();
  }

  Widget _todayClassList(BuildContext context, String today, List<dynamic> classes, List<dynamic> attendance) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Today's Classes",
        style: GoogleFonts.ropaSans(
          textStyle: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      SizedBox(height: 10.h),
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final classInfo = classes[index];
          final avatarColor = generateAvatarColor(classInfo['subject']);

          final attendanceStatus = attendance.firstWhere(
              (att) => att['subject'] == classInfo['subject'],
              orElse: () => null);

          String formattedTimestamp;
          if (attendanceStatus != null &&
              attendanceStatus['timestamp'] != null) {
            final timestamp = DateTime.parse(attendanceStatus['timestamp']);
            final now = DateTime.now();
            final difference = now.difference(timestamp);

            if (difference.inDays == 0) {
              formattedTimestamp = DateFormat('h:mm a').format(timestamp);
            } else if (difference.inDays == 1) {
              formattedTimestamp =
                  'Yesterday at ${DateFormat('h:mm a').format(timestamp)}';
            } else {
              formattedTimestamp =
                  DateFormat('MMM d, y h:mm a').format(timestamp);
            }
          } else {
            formattedTimestamp = 'N/A';
          }

          return Card(
            margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 5.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.r),
            ),
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(15.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: avatarColor,
                        child: Text(
                          classInfo['subject'][0],
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          classInfo['subject'],
                          style: TextStyle(
                              fontSize: 18.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (attendanceStatus == null ||
                          attendanceStatus['status'] == 'undecided')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () {
                                _scanFace(context, classInfo['subject'], today);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                context.read<AttendanceBloc>().add(
                                      UpdateAttendanceStatus(
                                          classInfo['subject'], 'absent', today),
                                    );
                              },
                            ),
                          ],
                        )
                      else
                        Text(
                          attendanceStatus != null
                              ? attendanceStatus['status'].toUpperCase()
                              : 'N/A',
                          style: TextStyle(
                            color: attendanceStatus != null &&
                                    attendanceStatus['status'] == 'present'
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16.sp, color: Colors.grey),
                      SizedBox(width: 5.w),
                      Expanded(
                        child: Text(
                          classInfo['time'],
                          style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  GestureDetector(
                    onTap: () => _launchLocation(classInfo['location']),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 16.sp, color: Colors.grey),
                        SizedBox(width: 5.w),
                        Expanded(
                          child: Text(
                            classInfo['location'],
                            style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[700],
                                decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (classInfo['place'] != null) ...[
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Icon(Icons.meeting_room, size: 16.sp, color: Colors.grey),
                        SizedBox(width: 5.w),
                        Expanded(
                          child: Text(
                            classInfo['place'],
                            style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (attendanceStatus != null &&
                      attendanceStatus['timestamp'] != null) ...[
                    SizedBox(height: 10.h),
                    Text(
                      "Marked at: $formattedTimestamp",
                      style: TextStyle(fontSize: 14.sp, color: Colors.green[700]),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}


  void _scheduleClassNotifications(Map<String, dynamic> weeklySchedule) {
    for (var entry in weeklySchedule.entries) {
      final day = entry.key;
      final classes = entry.value as List<dynamic>;

      for (var classInfo in classes) {
        final className = classInfo['subject'];
        final time = classInfo['time'];
        final scheduleDate = _getNextClassDate(day, time);
        NotificationService.scheduleClassReminder(
            className, time, scheduleDate);
      }
    }
  }

  DateTime _getNextClassDate(String day, String time) {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final classDay = days.indexOf(day) + 1;

    try {
      final cleanedTime = _cleanTimeString(time);
      final timeFormat = DateFormat('hh:mm a');

      DateTime classTime;

      try {
        print(
            'Attempting to parse time: "$cleanedTime" using DateFormat (hh:mm a)');
        classTime = timeFormat.parse(cleanedTime);
      } catch (e) {
        print('Failed to parse time using DateFormat (hh:mm a): $e');
        _debugTimeString(cleanedTime);
        throw FormatException('Unable to parse time: $cleanedTime');
      }

      print('Parsed time: $classTime for input: "$cleanedTime"');

      final classDate = DateTime(
          now.year, now.month, now.day, classTime.hour, classTime.minute);

      // Adjust the date to the correct day of the week
      int daysUntilClass = (classDay - now.weekday) % 7;
      if (daysUntilClass <= 0) {
        daysUntilClass += 7;
      }

      return classDate.add(Duration(days: daysUntilClass));
    } catch (e) {
      print('Failed to parse time: $time. Error: $e');
      _debugTimeString(time); // Add debug information
      return now; // Default to current time if parsing fails
    }
  }

  String _cleanTimeString(String time) {
    // Remove non-breaking spaces and other non-printable characters
    final cleanedTime = time.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    print('Cleaned time string: "$cleanedTime"');
    return cleanedTime;
  }

  void _debugTimeString(String time) {
    print('Debugging time string: "$time"');
    for (int i = 0; i < time.length; i++) {
      print('Character: "${time[i]}", Unicode: ${time.codeUnitAt(i)}');
    }
  }
}
