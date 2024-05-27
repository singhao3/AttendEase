import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

import '../../../bloc/attendance_bloc.dart';
import '../../../theming/colors.dart';

class WeeklyScheduleScreen extends StatelessWidget {
  final AttendanceBloc attendanceBloc;

  const WeeklyScheduleScreen({super.key, required this.attendanceBloc});

  Color generateAvatarColor(String subject) {
    final random = Random(subject.hashCode);
    final hue = random.nextDouble() * 360;
    return HSVColor.fromAHSV(1.0, hue, 0.8, 0.8).toColor();
  }

  List<String> getSortedDays() {
    return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: attendanceBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Weekly Schedule', style: GoogleFonts.ropaSans()),
          backgroundColor: ColorsManager.lightShadeOfGray,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.w),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BlocBuilder<AttendanceBloc, AttendanceState>(
                    builder: (context, state) {
                      if (state is AttendanceLoaded) {
                        final weeklySchedule = state.weeklySchedule;
                        final sortedDays = getSortedDays();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: sortedDays.map((day) {
                            final classes = weeklySchedule[day] ?? [];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "$day's Classes",
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
                                          child: Text(classInfo['subject'][0]), // First letter of subject
                                        ),
                                        title: Text("${classInfo['subject']}"),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Time: ${classInfo['time']}"),
                                            Text("Location: ${classInfo['location']}"),
                                          ],
                                        ),
                                        trailing: Text(
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
                                SizedBox(height: 20.h),
                              ],
                            );
                          }).toList(),
                        );
                      } else if (state is AttendanceError) {
                        return Center(
                          child: Text(
                            state.message,
                            style: TextStyle(color: Colors.red, fontSize: 18.sp),
                          ),
                        );
                      } else {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
