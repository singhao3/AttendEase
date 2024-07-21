import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_offline/flutter_offline.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../../../bloc/attendance_bloc.dart';
import '../../../core/widgets/no_internet.dart';
import '../../../core/widgets/user_profile_section.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/weekend_message.dart';
import '../../../theming/colors.dart';
import '/theming/styles.dart';
import '/helpers/firebase_helpers.dart';
import '../../../services/notification_service.dart';
import '../../../core/widgets/drawer.dart';
import '../../../utils/date_utils.dart' as custom_date_utils;
import '../../../core/widgets/reusable_widgets.dart';

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
    listenToAuthChanges();
    _loadAttendanceIfNotLoaded();
  }

  void listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && user.uid.isNotEmpty) {
        context.read<AttendanceBloc>().add(UpdateUserId(user.uid));
      }
    });
  }

  Future<void> fetchUserProfile() async {
    profileImageUrl = await firebaseHelpers.fetchUserProfileUrl();
    if (mounted) setState(() {});
  }

  void _loadAttendanceIfNotLoaded() {
    if (context.read<AttendanceBloc>().state is! AttendanceLoaded) {
      context.read<AttendanceBloc>().add(LoadAttendance());
    }
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

  Future<void> _scanFace(String subject, String day) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (mounted && image != null) {
      context
          .read<AttendanceBloc>()
          .add(ScanFaceForAttendance(image.path, subject, day));
    }
  }

  void _showDialog(String title, String description, DialogType dialogType) {
    if (!mounted) return;
    AwesomeDialog(
      context: context,
      dialogType: dialogType,
      animType: AnimType.rightSlide,
      title: title,
      desc: description,
      btnOkOnPress: () {
        _refreshAttendance();
      },
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorsManager.lightShadeOfGray,
        title: Text('AttendEase',
            style: GoogleFonts.ropaSans(
                textStyle: TextStyles.font24Blue700Weight)),
        centerTitle: true,
      ),
      drawer: CustomDrawer(refreshAttendance: _refreshAttendance),
      body: OfflineBuilder(
        connectivityBuilder: (
          BuildContext context,
          ConnectivityResult connectivity,
          Widget child,
        ) {
          final bool connected = connectivity != ConnectivityResult.none;
          return connected
              ? BlocConsumer<AttendanceBloc, AttendanceState>(
                  listener: _attendanceStateListener,
                  builder: _attendanceStateBuilder,
                )
              : const BuildNoInternet();
        },
        child: const LoadingIndicator(),
      ),
    );
  }

  void _attendanceStateListener(BuildContext context, AttendanceState state) {
    if (state is AttendanceError) {
      _showSnackBar(state.message);
    } else if (state is FaceScanFailed) {
      _showDialog('Face Scan Failed', state.message, DialogType.error);
    } else if (state is FaceScanSuccess) {
      _showDialog('Attendance Marked', state.message, DialogType.success);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _attendanceStateBuilder(BuildContext context, AttendanceState state) {
    if (state is AttendanceInitial || state is FaceScanInProgress) {
      return const LoadingIndicator();
    } else if (state is AttendanceLoaded) {
      _scheduleClassNotifications(state.registeredClasses);
      return _buildRefreshableHomePage(
          context, getToday(), state.registeredClasses, state.weeklyAttendance);
    } else if (state is AttendanceError) {
      return ErrorState(
        message: state.message,
        retry: _refreshAttendance,
      );
    } else {
      return const LoadingIndicator();
    }
  }

  Widget _buildRefreshableHomePage(BuildContext context, String today,
      List<dynamic> registeredClasses, Map<String, dynamic> weeklyAttendance) {
    return RefreshIndicator(
      onRefresh: _refreshAttendance,
      child: _homePage(context, today, registeredClasses, weeklyAttendance),
    );
  }

  SafeArea _homePage(BuildContext context, String today,
      List<dynamic> registeredClasses, Map<String, dynamic> weeklyAttendance) {
    final userName = FirebaseAuth.instance.currentUser!.displayName ?? 'John';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserProfileSection(profileImageUrl: profileImageUrl),
            SizedBox(height: 20.h),
            _welcomeText(userName),
            SizedBox(height: 20.h),
            Expanded(
              child: isWeekend()
                  ? const WeekendMessage()
                  : _todayClassList(
                      context, today, registeredClasses, weeklyAttendance),
            ),
          ],
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
            'Hello, $userName !',
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
            'Ready for your classes today?',
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

  Widget _todayClassList(BuildContext context, String today,
      List<dynamic> registeredClasses, Map<String, dynamic> weeklyAttendance) {
    final todayClasses = registeredClasses
        .where((classInfo) => classInfo['day'] == today)
        .toList();

    return todayClasses.isEmpty
        ? _buildNoClassesMessage()
        : ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: todayClasses.length,
            itemBuilder: (context, index) {
              final classInfo = todayClasses[index];
              final avatarColor = ReusableWidgets.generateAvatarColor(
                  classInfo['subject'],
                  classInfo['day'],
                  classInfo['startTime']);
              final attendanceStatus =
                  _getAttendanceStatus(weeklyAttendance, today, classInfo);

              return Card(
                elevation: 2,
                margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    // Add functionality to show more details or options
                  },
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: avatarColor,
                              radius: 24.r,
                              child: Text(
                                classInfo['subject'][0],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    classInfo['subject'],
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  ReusableWidgets.buildClassTimeRow(
                                    '${classInfo['startTime']} - ${classInfo['endTime']}',
                                  ),
                                ],
                              ),
                            ),
                            _buildAttendanceStatus(
                                context, attendanceStatus, classInfo, today),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        ReusableWidgets.buildLocationRow(classInfo['location']),
                        if (classInfo['roomNumber'] != null) ...[
                          SizedBox(height: 4.h),
                          ReusableWidgets.buildPlaceRow(
                              'Room ${classInfo['roomNumber']}'),
                        ],
                        if (attendanceStatus != null &&
                            attendanceStatus['timestamp'] != null) ...[
                          SizedBox(height: 8.h),
                          _buildAttendanceTimestamp(attendanceStatus),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildAttendanceStatus(BuildContext context, dynamic attendanceStatus,
      Map<String, dynamic> classInfo, String today) {
    final classStartTime =
        custom_date_utils.DateUtils.parseClassTime(classInfo['startTime']);
    final classEndTime =
        custom_date_utils.DateUtils.parseClassTime(classInfo['endTime']);
    final now = DateTime.now();
    final isWithinClassTime =
        now.isAfter(classStartTime) && now.isBefore(classEndTime);

    if (isWithinClassTime && attendanceStatus == null) {
      return ElevatedButton(
        child: const Text('Mark'),
        onPressed: () {
          // Show a dialog with options to mark attendance
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Mark Attendance'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.check, color: Colors.green),
                      title: const Text('Present'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _scanFace(classInfo['subject'], today);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.close, color: Colors.red),
                      title: const Text('Absent'),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.read<AttendanceBloc>().add(
                              UpdateAttendanceStatus(
                                  classInfo['subject'], 'absent', today),
                            );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: attendanceStatus != null
              ? _getStatusColor(attendanceStatus['status'])
              : Colors.grey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          attendanceStatus != null
              ? _capitalize(attendanceStatus['status'] ?? 'Marked')
              : 'N/A',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
        ),
      );
    }
  }

  Widget _buildNoClassesMessage() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 20.h),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 50.h),
                Icon(Icons.sentiment_very_satisfied,
                    size: 100.sp, color: Colors.blue[300]),
                SizedBox(height: 20.h),
                Text(
                  'No Classes Today!',
                  style: GoogleFonts.ropaSans(
                    textStyle: TextStyle(
                      fontSize: 24.sp,
                      color: Colors.blue[300],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                Text(
                  'Enjoy your day off or use this time to review and catch up on your studies.',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  dynamic _getAttendanceStatus(Map<String, dynamic> weeklyAttendance,
      String today, Map<String, dynamic> classInfo) {
    return (weeklyAttendance[today] ?? []).firstWhere(
      (att) => att['subject'] == classInfo['subject'],
      orElse: () => null,
    );
  }

  Text _buildAttendanceTimestamp(dynamic attendanceStatus) {
    final timestamp = DateTime.parse(attendanceStatus['timestamp']);
    final formattedTimestamp = _formatTimestamp(timestamp);

    return Text(
      "Marked at: $formattedTimestamp",
      style: TextStyle(fontSize: 16.sp, color: Colors.green[700]),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(timestamp)}';
    } else {
      return DateFormat('MMM d, y h:mm a').format(timestamp);
    }
  }

  String _capitalize(String status) {
    if (status.isEmpty) return status;
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.red;
    }
  }

  void _scheduleClassNotifications(List<dynamic> registeredClasses) {
    for (var classInfo in registeredClasses) {
      final className = classInfo['subject'];
      final time = '${classInfo['startTime']} - ${classInfo['endTime']}';
      final day = classInfo['day'];
      final scheduleDate = custom_date_utils.DateUtils.getNextClassDate(
          day, classInfo['startTime']);
      NotificationService.scheduleClassReminder(className, time, scheduleDate);
    }
  }
}
