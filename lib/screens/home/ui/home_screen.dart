// ignore_for_file: use_build_context_synchronously

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_offline/flutter_offline.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math';

import '../../../bloc/attendance_bloc.dart';
import '../../../core/widgets/no_internet.dart';
import '../../../theming/colors.dart';
import '/helpers/extensions.dart';
import '/routing/routes.dart';
import '/theming/styles.dart';
import '/helpers/firebase_helpers.dart';
import '../../weekly_schedule/weekly_schedule_screen.dart';

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
  }

  Future<void> fetchUserProfile() async {
    profileImageUrl = await firebaseHelpers.fetchUserProfileUrl();
    if (mounted) setState(() {});
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

  Future<void> _scanFace(BuildContext context, String subject, String day) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      context.read<AttendanceBloc>().add(ScanFaceForAttendance(image.path, subject, day));
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
          return connected ? _homePage(context, today) : const BuildNoInternet();
        },
        child: const Center(
          child: CircularProgressIndicator(
            color: ColorsManager.mainBlue,
          ),
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildUserHeader(),
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
            title: 'Sign Out',
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }

  UserAccountsDrawerHeader _buildUserHeader() {
    return UserAccountsDrawerHeader(
      accountName: Text(
        FirebaseAuth.instance.currentUser!.displayName ?? 'John Doe',
        style: GoogleFonts.ropaSans(),
      ),
      accountEmail: Text(
        FirebaseAuth.instance.currentUser!.email ?? 'john.doe@graduate.utm.my',
        style: GoogleFonts.ropaSans(),
      ),
      currentAccountPicture: CircleAvatar(
        backgroundImage: profileImageUrl != null
            ? NetworkImage(profileImageUrl!)
            : const AssetImage('assets/images/placeholder.jpg')
                as ImageProvider,
      ),
      onDetailsPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileEditScreen(),
          ),
        );
      },
    );
  }

  ListTile _buildDrawerItem({required String title, required VoidCallback onTap}) {
    return ListTile(
      title: Text(title, style: GoogleFonts.ropaSans()),
      onTap: onTap,
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      GoogleSignIn().disconnect();
      FirebaseAuth.instance.signOut();
      context.pushNamedAndRemoveUntil(
        Routes.loginScreen,
        predicate: (route) => false,
      );
    } catch (e) {
      Navigator.of(context).pop();
      await AwesomeDialog(
        context: context,
        dialogType: DialogType.info,
        animType: AnimType.rightSlide,
        title: 'Sign out error',
        desc: e.toString(),
      ).show();
    }
  }

  SafeArea _homePage(BuildContext context, String today) {
    final userName = FirebaseAuth.instance.currentUser!.displayName ?? 'John';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15.w),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _userProfileSection(),
              SizedBox(height: 20.h),
              _welcomeText(userName),
              SizedBox(height: 20.h),
              _todayClassList(context, today),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userProfileSection() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30.w,
            backgroundImage: profileImageUrl != null
                ? NetworkImage(profileImageUrl!)
                : const AssetImage('assets/images/placeholder.jpg')
                    as ImageProvider,
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                FirebaseAuth.instance.currentUser!.displayName ?? 'John Doe',
                style: GoogleFonts.ropaSans(
                  textStyle: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                FirebaseAuth.instance.currentUser!.email ??
                    'john.doe@graduate.utm.my',
                style: GoogleFonts.ropaSans(
                  textStyle: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
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

  Widget _todayClassList(BuildContext context, String today) {
    return BlocConsumer<AttendanceBloc, AttendanceState>(
      listener: (context, state) {
        if (state is FaceScanFailed) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is AttendanceError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is AttendanceLoaded) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Attendance updated successfully!")));
        }
      },
      builder: (context, state) {
        if (state is FaceScanInProgress) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else if (state is AttendanceLoaded) {
          final classes = state.weeklySchedule[today] ?? [];

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

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.h),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: avatarColor,
                        child: Text(classInfo['subject'][0]), 
                      ),
                      title: Text("${classInfo['subject']}"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Time: ${classInfo['time']}"),
                          Text("Location: ${classInfo['location']}"),
                        ],
                      ),
                      trailing: classInfo['status'] == 'undecided'
                          ? Row(
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
                                          UpdateAttendanceStatus(classInfo['subject'], 'absent', today),
                                        );
                                  },
                                ),
                              ],
                            )
                          : Text(
                              classInfo['status'].toUpperCase(),
                              style: TextStyle(
                                color: classInfo['status'] == 'present' ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ],
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}

class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.ropaSans()),
      ),
      body: Center(
        child: Text(
          'Profile Editing Screen',
          style: GoogleFonts.ropaSans(
            textStyle: TextStyle(
              fontSize: 20.sp,
            ),
          ),
        ),
      ),
    );
  }
}
