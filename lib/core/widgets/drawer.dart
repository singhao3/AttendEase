import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/widgets/sign_out.dart';
import '../../../../theming/colors.dart';
import '../../../../core/widgets/user_header.dart';
import '../../bloc/attendance_bloc.dart';
import '../../screens/attendance_history/attendance_history_screen.dart';
import '../../screens/report/generate_report_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/weekly_schedule/weekly_schedule_screen.dart';

class CustomDrawer extends StatelessWidget {
  final Future<void> Function() refreshAttendance;

  const CustomDrawer({super.key, required this.refreshAttendance});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: <Widget>[
          const UserHeader(backgroundColor: ColorsManager.mainBlue),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                _buildDrawerItem(
                  icon: FontAwesomeIcons.house,
                  title: 'Home',
                  onTap: () => Navigator.of(context).pop(),
                ),
                _buildDrawerItem(
                  icon: FontAwesomeIcons.calendarWeek,
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
                  icon: FontAwesomeIcons.clockRotateLeft,
                  title: 'Attendance History',
                  onTap: () {
                    _navigateToAttendanceHistoryScreen(context);
                  },
                ),
                _buildDrawerItem(
                  icon: FontAwesomeIcons.filePdf,
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
                  icon: FontAwesomeIcons.gear,
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
                  icon: FontAwesomeIcons.rightFromBracket,
                  title: 'Sign Out',
                  onTap: () => SignOut.signOut(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAttendanceHistoryScreen(BuildContext context) {
    final studentId = FirebaseAuth.instance.currentUser!.uid;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceHistoryScreen(studentId: studentId),
      ),
    ).then((_) {
      refreshAttendance();
    });
  }

  ListTile _buildDrawerItem(
      {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: ColorsManager.mainBlue),
      title: Text(title, style: GoogleFonts.ropaSans()),
      onTap: onTap,
    );
  }
}
